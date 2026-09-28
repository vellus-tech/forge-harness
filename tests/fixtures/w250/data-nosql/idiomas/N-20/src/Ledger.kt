session.withTransaction({ col.insertOne(session, entry) }, TransactionOptions.builder().readConcern(ReadConcern.LOCAL).build())
