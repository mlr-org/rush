# rush: Rapid Asynchronous and Distributed Computing

Package to tackle large-scale problems asynchronously across a
distributed network. Employing a database centric model, rush enables
workers to communicate tasks and their results over a shared 'Redis'
database. Key features include low task overhead, efficient caching, and
robust error handling. The package powers the asynchronous optimization
algorithms in the 'bbotk' and 'mlr3tuning' packages.

## Options

- `rush.max_object_size`: Maximum size in MiB of the serialized worker
  configuration stored in Redis. Defaults to `512`. If the configuration
  exceeds this limit, an error is raised unless `large_objects_path` is
  set in
  [`rush_plan()`](https://rush.mlr-org.com/dev/reference/rush_plan.md),
  in which case the configuration is written to disk instead.

## Environment Variables

- `REDIS_URL`: Connection URL parsed by
  [redux::redis_config](https://richfitz.github.io/redux/reference/redis_config.html)
  to configure the connection to Redis. Used when no `config` is set via
  [`rush_plan()`](https://rush.mlr-org.com/dev/reference/rush_plan.md).
  If unset, a default configuration is used.

## See also

Useful links:

- <https://rush.mlr-org.com>

- <https://github.com/mlr-org/rush>

- Report bugs at <https://github.com/mlr-org/rush/issues>

## Author

**Maintainer**: Marc Becker <marcbecker@posteo.de>
([ORCID](https://orcid.org/0000-0002-8115-0400)) \[copyright holder\]

Authors:

- Marc Becker <marcbecker@posteo.de>
  ([ORCID](https://orcid.org/0000-0002-8115-0400)) \[copyright holder\]
