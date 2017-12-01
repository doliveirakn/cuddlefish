# Support for running ActiveRecord migrations on their appropriate shards.

module ActiveRecord
  class MigrationProxy
    def tags
      @tags = Cuddlefish.tags_for_migration.call(self).map(&:to_sym) if !defined?(@tag)
      @tags
    end
  end

  class Migration
    alias_method :original_announce, :announce

    def announce(message)
      host, db = connection.raw_connection.query_options.values_at(:host, :database)
      original_announce("[#{host}.#{db}] #{message}")
    end
  end

  class Migrator
    # This is a monkey-patch. The previous version (in 4.2.8) was:
    #
    # def execute_migration_in_transaction(migration, direction)
    #   ddl_transaction(migration) do
    #     migration.migrate(direction)
    #     record_version_state_after_migrating(migration.version)
    #   end
    # end

    def execute_migration_in_transaction(migration, direction)
      Cuddlefish.force_shard_tags(*migration.tags) do
        ddl_transaction(migration) do
          migration.migrate(direction)
          record_version_state_after_migrating(migration.version)
        end
      end
    end
  end
end
