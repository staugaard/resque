module Resque
  module Jobs
    # If you want only one instance of your job running at a time,
    # inherit from this class.
    #
    # For example:
    #
    # class UpdateNetworkGraph < Resque::Jobs::Locked
    #   def self.perform(repo_id)
    #     heavy_lifting
    #   end
    # end
    #
    # While other UpdateNetworkGraph jobs will be placed on the queue,
    # the Locked class will check Redis to see if any others are
    # executing with the same arguments before beginning. If another
    # is executing the job will be aborted.
    #
    # If you want to define the key yourself you can override the
    # `lock` class method in your subclass, e.g.
    #
    # class UpdateNetworkGraph < Resque::Jobs::Locked
    #   # Run only one at a time, regardless of repo_id.
    #   def self.lock(repo_id)
    #     "network-graph"
    #   end
    #
    #   def self.perform(repo_id)
    #     heavy_lifting
    #   end
    # end
    #
    # The above modification will ensure only one job of class
    # UpdateNetworkGraph is running at a time, regardless of the
    # repo_id. Normally a job is locked using a combination of its
    # class name and arguments.
    class Locked
      # Override in your subclass to control the lock key. It is
      # passed the same arguments as `perform`, that is, your job's
      # payload.
      def self.lock(*args)
        "locked:#{name}-#{args.to_s}"
      end

      # Convenience method, not used internally.
      def self.locked?
        Resque.redis.exist(lock)
      end

      # Where the magic happens.
      def self.around_perform(*args)
        # Abort if another job has created a lock.
        return unless Resque.redis.setnx(lock, true)

        begin
          yield
        ensure
          # Always clear the lock when we're done, even if there is an
          # error.
          Resque.redis.del(lock)
        end
      end
    end
  end
end
