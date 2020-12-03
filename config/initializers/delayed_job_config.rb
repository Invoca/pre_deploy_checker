# frozen_string_literal: true

Delayed::Worker.max_run_time = 15.minutes
Delayed::Worker.max_attempts = 2
Delayed::Worker.raise_signal_exceptions = :term
