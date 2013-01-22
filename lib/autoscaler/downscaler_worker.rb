module Autoscaler
  class DownscalerWorker
    include ::Sidekiq::Worker

    sidekiq_options :queue => :downscale

    def perform(scaler, timeout, specified_queues = nil)
      @specified_queues = specified_queues

      unless pending_work? || scheduled_work? || retry_work?
        scaler.workers = 0
      else
        self.schedule_downscaler(timeout, specified_queues)
      end
    end

    def self.schedule(scaler, timeout, specified_queues = nil)
      kill_previously_scheduled_downscale_job
      perform_in timeout, scaler, timeout, specified_queues
    end

    private

    def self.kill_previously_scheduled_downscale_job
      ::Sidekiq::ScheduledSet.new.any?{ |job| job.queue == "downscale" and job.delete }
    end

    def queues
      @specified_queues || registered_queues
    end

    def registered_queues
      ::Sidekiq.redis { |x| x.smembers('queues') }
    end

    def empty?(name)
      ::Sidekiq.redis { |conn| conn.llen("queue:#{name}") == 0 }
    end

    def scheduled_work?
      ::Sidekiq.redis { |c| c.zcard("schedule") > 0 }
    end

    def retry_work?
      ::Sidekiq.redis { |c| c.zcard("retry") > 0 }
    end

    def pending_work?
      queues.any? {|q| !empty?(q)}
    end
  end
end
