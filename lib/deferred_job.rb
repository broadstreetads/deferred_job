require 'bundler/setup'
require 'resque'

begin
  require 'active_support/core_ext/string/inflections'
rescue LoadError
  require 'active_support'
end

module Resque

  class NoSuchKey < StandardError
  end

  class DeferredJob

    VERSION = [0, 0, 1]

    include Helpers

    attr_accessor :verbose
    attr_reader :id, :klass, :args

    # Initialize a new DeferredJob
    # @param [String] id - The ID of the job
    # @param [Class, String] klass - The class to run
    # @param [Array] args - The arguments for the job
    def initialize(id, klass, *args)
      @id = id
      @set_key = "#{id}-set"
      @klass = klass.is_a?(String) ? klass.constantize : klass
      @args = args
    end

    # Clear all entries in the set
    def clear
      redis.del @set_key
    end

    # Clear and then remove the key for this job
    def destroy
      redis.del @set_key
      redis.del @id
    end

    # Determine if the set is empty
    # @return [Boolean] whether or not the set is empty
    def empty?
      count == 0
    end

    # Count the number of elements in the set
    # @return [Fixnum] the count of the elements in the set
    def count
      redis.scard(@set_key).to_i
    end

    # Wait for a thing before continuing
    # @param [Array] things - The things to add
    # @return [Fixnum] the number of things added
    # NOTE >= 2.4 should use sadd with multiple things
    def wait_for(*things)
      things.each do |thing|
        log("DeferredJob #{@id} will wait for #{thing.inspect}")
        redis.sadd @set_key, thing
      end
    end

    def waiting_for?(thing)
      redis.sismember(@set_key, thing)
    end

    def waiting_for
      redis.smembers(@set_key)
    end

    # Mark a thing as finished
    # @param [Array] things - The things to remove
    # @return [Fixnum] the number of things removed
    # NOTE >= 2.4 should use srem with multiple things
    def done(*things)
      results = redis.multi do
        redis.scard @set_key
        things.each do |thing|
          log "DeferredJob #{id} done with #{thing.inspect}"
          redis.srem @set_key, thing
        end
        redis.scard @set_key
      end
      if results.first > 0
        if results.last.zero?
          log "DeferredJob #{id} all conditions met; will now self-destruct"
          begin
            execute
          ensure
            destroy
          end
        else
          log "DeferredJob #{id} waiting on #{results.last} conditions"
        end
      end
    end

    # Create a new DeferredJob
    # @param [String] id - the id of the job
    # @param [Class, String] klass - The class of the job to run
    # @param [Array] args - The args to send to the job
    # @return [Resque::DeferredJob] - the job, cleared
    def self.create(id, klass, *args)
      plan = [klass.to_s, args]
      Resque.redis.set(id, MultiJson.encode(plan))
      # Return the job
      job = new id, klass, *args
      job.clear
      job
    end

    # Find an existing DeferredJob
    # @param [String] id - the id of the job
    # @return [Resque::DeferredJob] - the job
    def self.find(id)
      plan_data = Resque.redis.get(id)
      # If found, return the job, otherwise raise NoSuchKey
      if plan_data.nil?
        raise ::Resque::NoSuchKey.new "No Such DeferredJob: #{id}"
      else
        plan = MultiJson.decode(plan_data)
        new id, plan.first, *plan.last
      end
    end

    def self.exists?(id)
      !Resque.redis.get(id).nil?
    end

    def self.version
      VERSION.join '.'
    end

    # Don't allow new instances
    private_class_method :new

    private

    # How to log - mirrors a pattern in resque
    def log(msg)
      if verbose
        if defined?(Rails)
          Rails.logger.debug(msg)
        else
          puts msg
        end
      end
    end

    # Execute the job with resque
    def execute
      Resque.enqueue klass, *args
    end

  end

end