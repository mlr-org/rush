# Changelog

## rush (development version)

- feat: Add `$push_finished_tasks()` method.

## rush 0.4.1

CRAN release: 2025-11-06

- feat: The `$wait_for_workers()` method can now wait for a specific
  number of workers or a specific set of worker ids. The workers are
  checked for registration in the network now.

## rush 0.4.0

CRAN release: 2025-10-08

feat: Add `$empty_queue()` method. fix: Queued tasks can be moved to
failed now.

## rush 0.3.1

CRAN release: 2025-09-16

feat: Change default of `n_workers`.

## rush 0.3.0

CRAN release: 2025-07-31

- feat: Output and message logs can be written to files now via the
  `message_log` and `output_log` arguments.
- compatibility: lgr 0.5.0
- BREAKING CHANGE: The mlr3 ecosystem has a base logger now which is
  named `mlr3`. The `mlr3/rush` logger is a child of the `mlr3` logger
  and is used for logging messages from the `rush` package.

## rush 0.2.0

CRAN release: 2025-05-30

- feat: Worker can be started with the `mirai` package now.

## rush 0.1.2

CRAN release: 2024-11-06

- feat: Add `$reconnect()` method.

## rush 0.1.1

CRAN release: 2024-07-05

- fix: `Rush` class was not exported.
- fix: `R6` package was not imported.

## rush 0.1.0

CRAN release: 2024-06-20

- Initial CRAN submission.
