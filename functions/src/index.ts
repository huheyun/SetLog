import { initializeApp } from "firebase-admin/app";
import { getFirestore, QueryDocumentSnapshot } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { logger } from "firebase-functions/v2";
import { setGlobalOptions } from "firebase-functions/v2/options";
import { onDocumentDeleted } from "firebase-functions/v2/firestore";

initializeApp();
setGlobalOptions({ maxInstances: 10 });

const db = getFirestore();

/**
 * When a group document is deleted, clean up everything that belonged to it:
 *  - posts/{postId} where groupID == groupId (including the reactions subcollection)
 *  - any leftover groups/{groupId}/members/* documents
 *  - Storage objects under videos/{groupId}/
 *
 * Idempotent: every step only deletes what still exists, so retries / duplicate
 * event deliveries are harmless.
 */
export const onGroupDeleted = onDocumentDeleted(
  {
    document: "groups/{groupId}",
    timeoutSeconds: 540,
    memory: "512MiB",
    retry: true,
  },
  async (event) => {
    const groupId = event.params.groupId;
    logger.info("Cleaning up deleted group", { groupId });

    // Count failures but don't throw from inside the BulkWriter error handler;
    // we throw at the end so the event is retried.
    let failedWrites = 0;
    const bulkWriter = db.bulkWriter();
    bulkWriter.onWriteError((error) => {
      if (error.failedAttempts < 5) {
        return true; // retry this write
      }
      failedWrites += 1;
      logger.error("Failed to delete document", {
        groupId,
        path: error.documentRef.path,
        code: error.code,
        message: error.message,
      });
      return false;
    });

    // 1. Posts (+ reactions). Page through in chunks so very large groups are fine.
    let postCount = 0;
    const pageSize = 300;
    const postsQuery = db
      .collection("posts")
      .where("groupID", "==", groupId)
      .orderBy("__name__")
      .limit(pageSize);

    let lastDoc: QueryDocumentSnapshot | undefined;
    while (true) {
      const page = await (lastDoc ? postsQuery.startAfter(lastDoc) : postsQuery).get();
      if (page.empty) break;

      await Promise.all(page.docs.map((doc) => db.recursiveDelete(doc.ref, bulkWriter)));
      postCount += page.size;
      lastDoc = page.docs[page.docs.length - 1];
      if (page.size < pageSize) break;
    }

    // 2. Leftover members subcollection (the app normally deletes these in the
    //    same batch as the group, but clients can fail half-way).
    const membersRef = db.collection("groups").doc(groupId).collection("members");
    const memberCount = (await membersRef.count().get()).data().count;
    if (memberCount > 0) {
      await db.recursiveDelete(membersRef, bulkWriter);
    }

    await bulkWriter.close();

    // 3. Storage objects.
    const bucket = getStorage().bucket();
    const prefix = `videos/${groupId}/`;
    const [files] = await bucket.getFiles({ prefix });
    if (files.length > 0) {
      await bucket.deleteFiles({ prefix, force: true });
    }

    logger.info("Group cleanup finished", {
      groupId,
      deletedPosts: postCount,
      deletedMemberDocs: memberCount,
      deletedStorageFiles: files.length,
      failedWrites,
    });

    if (failedWrites > 0) {
      throw new Error(`Group cleanup for ${groupId} had ${failedWrites} failed writes; retrying.`);
    }
  }
);
