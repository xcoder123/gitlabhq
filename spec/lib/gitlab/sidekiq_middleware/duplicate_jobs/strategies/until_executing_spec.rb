# frozen_string_literal: true

require 'fast_spec_helper'
require 'timecop'

describe Gitlab::SidekiqMiddleware::DuplicateJobs::Strategies::UntilExecuting do
  let(:fake_duplicate_job) do
    instance_double(Gitlab::SidekiqMiddleware::DuplicateJobs::DuplicateJob)
  end

  subject(:strategy) { described_class.new(fake_duplicate_job) }

  describe '#schedule' do
    before do
      allow(Gitlab::SidekiqLogging::DeduplicationLogger.instance).to receive(:log)
    end

    it 'checks for duplicates before yielding' do
      expect(fake_duplicate_job).to receive(:scheduled?).twice.ordered.and_return(false)
      expect(fake_duplicate_job).to(
        receive(:check!)
          .with(Gitlab::SidekiqMiddleware::DuplicateJobs::DuplicateJob::DUPLICATE_KEY_TTL)
          .ordered
          .and_return('a jid'))
      expect(fake_duplicate_job).to receive(:duplicate?).ordered.and_return(false)

      expect { |b| strategy.schedule({}, &b) }.to yield_control
    end

    it 'checks worker options for scheduled jobs' do
      expect(fake_duplicate_job).to receive(:scheduled?).ordered.and_return(true)
      expect(fake_duplicate_job).to receive(:options).ordered.and_return({})
      expect(fake_duplicate_job).not_to receive(:check!)

      expect { |b| strategy.schedule({}, &b) }.to yield_control
    end

    context 'job marking' do
      it 'adds the jid of the existing job to the job hash' do
        allow(fake_duplicate_job).to receive(:scheduled?).and_return(false)
        allow(fake_duplicate_job).to receive(:check!).and_return('the jid')
        allow(fake_duplicate_job).to receive(:droppable?).and_return(true)
        job_hash = {}

        expect(fake_duplicate_job).to receive(:duplicate?).and_return(true)
        expect(fake_duplicate_job).to receive(:existing_jid).and_return('the jid')

        strategy.schedule(job_hash) {}

        expect(job_hash).to include('duplicate-of' => 'the jid')
      end

      context 'scheduled jobs' do
        let(:time_diff) { 1.minute }

        context 'scheduled in the past' do
          it 'adds the jid of the existing job to the job hash' do
            allow(fake_duplicate_job).to receive(:scheduled?).twice.and_return(true)
            allow(fake_duplicate_job).to receive(:scheduled_at).and_return(Time.now - time_diff)
            allow(fake_duplicate_job).to receive(:options).and_return({ including_scheduled: true })
            allow(fake_duplicate_job).to(
              receive(:check!)
                .with(Gitlab::SidekiqMiddleware::DuplicateJobs::DuplicateJob::DUPLICATE_KEY_TTL)
                .and_return('the jid'))
            allow(fake_duplicate_job).to receive(:droppable?).and_return(true)
            job_hash = {}

            expect(fake_duplicate_job).to receive(:duplicate?).and_return(true)
            expect(fake_duplicate_job).to receive(:existing_jid).and_return('the jid')

            strategy.schedule(job_hash) {}

            expect(job_hash).to include('duplicate-of' => 'the jid')
          end
        end

        context 'scheduled in the future' do
          it 'adds the jid of the existing job to the job hash' do
            Timecop.freeze do
              allow(fake_duplicate_job).to receive(:scheduled?).twice.and_return(true)
              allow(fake_duplicate_job).to receive(:scheduled_at).and_return(Time.now + time_diff)
              allow(fake_duplicate_job).to receive(:options).and_return({ including_scheduled: true })
              allow(fake_duplicate_job).to(
                receive(:check!).with(time_diff.to_i).and_return('the jid'))
              allow(fake_duplicate_job).to receive(:droppable?).and_return(true)
              job_hash = {}

              expect(fake_duplicate_job).to receive(:duplicate?).and_return(true)
              expect(fake_duplicate_job).to receive(:existing_jid).and_return('the jid')

              strategy.schedule(job_hash) {}

              expect(job_hash).to include('duplicate-of' => 'the jid')
            end
          end
        end
      end
    end

    context "when the job is droppable" do
      before do
        allow(fake_duplicate_job).to receive(:scheduled?).and_return(false)
        allow(fake_duplicate_job).to receive(:check!).and_return('the jid')
        allow(fake_duplicate_job).to receive(:duplicate?).and_return(true)
        allow(fake_duplicate_job).to receive(:existing_jid).and_return('the jid')
        allow(fake_duplicate_job).to receive(:droppable?).and_return(true)
      end

      it 'drops the job' do
        schedule_result = nil

        expect(fake_duplicate_job).to receive(:droppable?).and_return(true)

        expect { |b| schedule_result = strategy.schedule({}, &b) }.not_to yield_control
        expect(schedule_result).to be(false)
      end

      it 'logs that the job was dropped' do
        fake_logger = instance_double(Gitlab::SidekiqLogging::DeduplicationLogger)

        expect(Gitlab::SidekiqLogging::DeduplicationLogger).to receive(:instance).and_return(fake_logger)
        expect(fake_logger).to receive(:log).with(a_hash_including({ 'jid' => 'new jid' }), 'dropped until executing')

        strategy.schedule({ 'jid' => 'new jid' }) {}
      end
    end
  end

  describe '#perform' do
    it 'deletes the lock before executing' do
      expect(fake_duplicate_job).to receive(:delete!).ordered
      expect { |b| strategy.perform({}, &b) }.to yield_control
    end
  end
end
