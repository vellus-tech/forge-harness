session.startTransaction({ readConcern: { level: "snapshot" }, writeConcern: { w: "majority" } });
await session.commitTransaction();
