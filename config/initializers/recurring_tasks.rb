# Load recurring tasks from config/recurring.yml into SolidQueue recurring tasks.
# This makes sure scheduled commands like ForecastRunnerJob are registered.
begin
  if defined?(SolidQueue::RecurringTask)
    cfg_path = Rails.root.join('config', 'recurring.yml')
    if File.exist?(cfg_path)
      cfg = YAML.load_file(cfg_path) || {}
      env_cfg = cfg[Rails.env] || {}
      env_cfg.each do |key, task_def|
        begin
          task = SolidQueue::RecurringTask.find_or_initialize_by(key: "#{Rails.env}:#{key}")
          task.command = task_def['command'] if task_def['command']
          task.schedule = task_def['schedule'] if task_def['schedule']
          task.priority = task_def['priority'] if task_def.key?('priority')
          task.queue_name = task_def['queue'] if task_def['queue']
          task.description = task_def['description'] if task_def['description']
          task.static = true
          task.save! if task.changed?
        rescue StandardError => e
          Rails.logger.warn "Failed to register recurring task #{key}: #{e.message}"
        end
      end
    end
  end
rescue StandardError => e
  Rails.logger.warn "Recurring tasks initializer error: #{e.message}"
end
