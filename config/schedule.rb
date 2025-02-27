# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
# set :output, "/path/to/my/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end
#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end

env "MAILTO", ""

# Learn more: http://github.com/javan/whenever

every 1.minute do
  command "date > ~/cron-test.txt"
end

every 1.day, at: "5:00 am" do
  rake "-s sitemap:refresh"
end

every 2.hours do
  rake "-s stats:generate"
end

# Temporally not send dashboard's notifications
# every 1.day, at: "7:00 am" do
#   rake "dashboards:send_notifications"
# end

every 1.day, at: "1:00 am", roles: [:cron] do
  rake "files:remove_old_cached_attachments"
end

every 1.day, at: "3:00 am", roles: [:cron] do
  rake "votes:reset_hot_score"
end

every :reboot do
  # Number of workers must be kept in sync with capistrano's delayed_job_workers
  # command "cd #{@path} && RAILS_ENV=#{@environment} bin/delayed_job -n 2 restart"
end

every 1.day, at: "2:30 am", roles: [:cron] do
  rake "projekt_phases:check_currentness_change"
end

every 1.day, at: "6:00 am", roles: [:cron] do
  rake "reminders:overdue_deficiency_reports"
  rake "reminders:not_assigned_deficiency_reports"
end

every 1.day, at: "3:00 am", roles: [:cron] do
  rake "maintenance:reverify_users"
end

every 1.day, at: "2:00 pm", roles: [:cron] do
  runner "NotificationServices::NewCommentsDeficiencyReportsNotification.call"
end
