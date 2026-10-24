require "test_helper"

class FoundationProbeJobTest < ActiveSupport::TestCase
  test "enqueued_probe_is_persisted_in_postgresql" do
    assert_equal :solid_queue, Rails.application.config.active_job.queue_adapter
    before = SolidQueue::Job.count
    job = FoundationProbeJob.perform_later
    assert job.successfully_enqueued?
    assert_equal before + 1, SolidQueue::Job.count
    row = SolidQueue::Job.find_by!(active_job_id: job.job_id)
    assert_equal "FoundationProbeJob", row.class_name
    row.destroy!
  end
end
