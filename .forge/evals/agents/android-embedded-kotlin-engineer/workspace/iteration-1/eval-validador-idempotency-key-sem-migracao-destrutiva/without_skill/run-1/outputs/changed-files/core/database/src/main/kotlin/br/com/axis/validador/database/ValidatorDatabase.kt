package br.com.axis.validador.database

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase

@Database(entities = [ValidationEventEntity::class], version = 4, exportSchema = true)
abstract class ValidatorDatabase : RoomDatabase() {
    abstract fun validationEventDao(): ValidationEventDao

    companion object {
        fun build(context: Context): ValidatorDatabase =
            Room.databaseBuilder(context, ValidatorDatabase::class.java, "validator.db")
                .addMigrations(*ALL_MIGRATIONS)
                .build()
    }
}
