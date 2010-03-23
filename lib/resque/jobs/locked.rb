module Resque
  module Jobs
    # If you want only one instance of your job running at a time,
    # extend your class with this module and that's it!
    #
    # For example:
    #
    # class UpdateNetworkGraph
    #   extend Resque::Jobs::Locked
    #
    #   def self.perform(repo_id)
    #     heavy_lifting
    #   end
    # end
    #
    # While other UpdateNetworkGraph jobs will be placed on the queue,
    # the Locked module will check Redis to see if any others are
    # executing with the same arguments before beginning. If another
    # is executing the job will be aborted.
    #
    # If you want to define the key yourself you can override the
    # `lock` class method in your subclass, e.g.
    #
    # class UpdateNetworkGraph
    #   extend Resque::Jobs::Locked
    #
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
    module Locked
      # Override in your job class to control the lock key. It is
      # passed the same arguments as `perform`.
      def lock(*args)
        "locked:#{name}-#{args.to_s}"
      end

      # Convenience method, not used internally.
      def locked?
        Resque.redis.exist(lock)
      end

      # Do not override - this is where the magic happens. Instead
      # provide your own `perform_without_lock` class level method.
      def around_perform(*args)
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
