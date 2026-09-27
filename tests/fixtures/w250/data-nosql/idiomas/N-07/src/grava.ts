import { MongoClient } from "mongodb"; // w250:contexto
await col.insertOne(doc, { w: 1 });
