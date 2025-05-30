% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/AppenderRedis.R
\name{AppenderRedis}
\alias{AppenderRedis}
\title{Log to Redis Database}
\value{
Object of class \link[R6:R6Class]{R6::R6Class} and \code{AppenderRedis} with methods for writing log events to Redis data bases.
}
\description{
\link{AppenderRedis} writes log messages to a Redis data base.
This \link[lgr:Appender]{lgr::Appender} is created internally by \link{RushWorker} when logger thresholds are passed via \code{\link[=rush_plan]{rush_plan()}}.
}
\examples{
# This example is not executed since Redis must be installed
\donttest{
   config_local = redux::redis_config()

   rush_plan(
     config = config_local,
     n_workers = 2,
     lgr_thresholds = c(rush = "info"))

   rush = rsh(network_id = "test_network")
   rush
}
}
\section{Super classes}{
\code{\link[lgr:Filterable]{lgr::Filterable}} -> \code{\link[lgr:Appender]{lgr::Appender}} -> \code{\link[lgr:AppenderMemory]{lgr::AppenderMemory}} -> \code{AppenderRedis}
}
\section{Methods}{
\subsection{Public methods}{
\itemize{
\item \href{#method-AppenderRedis-new}{\code{AppenderRedis$new()}}
\item \href{#method-AppenderRedis-flush}{\code{AppenderRedis$flush()}}
}
}
\if{html}{\out{
<details><summary>Inherited methods</summary>
<ul>
<li><span class="pkg-link" data-pkg="lgr" data-topic="Filterable" data-id="add_filter"><a href='../../lgr/html/Filterable.html#method-Filterable-add_filter'><code>lgr::Filterable$add_filter()</code></a></span></li>
<li><span class="pkg-link" data-pkg="lgr" data-topic="Filterable" data-id="filter"><a href='../../lgr/html/Filterable.html#method-Filterable-filter'><code>lgr::Filterable$filter()</code></a></span></li>
<li><span class="pkg-link" data-pkg="lgr" data-topic="Filterable" data-id="remove_filter"><a href='../../lgr/html/Filterable.html#method-Filterable-remove_filter'><code>lgr::Filterable$remove_filter()</code></a></span></li>
<li><span class="pkg-link" data-pkg="lgr" data-topic="Filterable" data-id="set_filters"><a href='../../lgr/html/Filterable.html#method-Filterable-set_filters'><code>lgr::Filterable$set_filters()</code></a></span></li>
<li><span class="pkg-link" data-pkg="lgr" data-topic="Appender" data-id="set_layout"><a href='../../lgr/html/Appender.html#method-Appender-set_layout'><code>lgr::Appender$set_layout()</code></a></span></li>
<li><span class="pkg-link" data-pkg="lgr" data-topic="Appender" data-id="set_threshold"><a href='../../lgr/html/Appender.html#method-Appender-set_threshold'><code>lgr::Appender$set_threshold()</code></a></span></li>
<li><span class="pkg-link" data-pkg="lgr" data-topic="AppenderMemory" data-id="append"><a href='../../lgr/html/AppenderMemory.html#method-AppenderMemory-append'><code>lgr::AppenderMemory$append()</code></a></span></li>
<li><span class="pkg-link" data-pkg="lgr" data-topic="AppenderMemory" data-id="clear"><a href='../../lgr/html/AppenderMemory.html#method-AppenderMemory-clear'><code>lgr::AppenderMemory$clear()</code></a></span></li>
<li><span class="pkg-link" data-pkg="lgr" data-topic="AppenderMemory" data-id="format"><a href='../../lgr/html/AppenderMemory.html#method-AppenderMemory-format'><code>lgr::AppenderMemory$format()</code></a></span></li>
<li><span class="pkg-link" data-pkg="lgr" data-topic="AppenderMemory" data-id="set_buffer_size"><a href='../../lgr/html/AppenderMemory.html#method-AppenderMemory-set_buffer_size'><code>lgr::AppenderMemory$set_buffer_size()</code></a></span></li>
<li><span class="pkg-link" data-pkg="lgr" data-topic="AppenderMemory" data-id="set_flush_on_exit"><a href='../../lgr/html/AppenderMemory.html#method-AppenderMemory-set_flush_on_exit'><code>lgr::AppenderMemory$set_flush_on_exit()</code></a></span></li>
<li><span class="pkg-link" data-pkg="lgr" data-topic="AppenderMemory" data-id="set_flush_on_rotate"><a href='../../lgr/html/AppenderMemory.html#method-AppenderMemory-set_flush_on_rotate'><code>lgr::AppenderMemory$set_flush_on_rotate()</code></a></span></li>
<li><span class="pkg-link" data-pkg="lgr" data-topic="AppenderMemory" data-id="set_flush_threshold"><a href='../../lgr/html/AppenderMemory.html#method-AppenderMemory-set_flush_threshold'><code>lgr::AppenderMemory$set_flush_threshold()</code></a></span></li>
<li><span class="pkg-link" data-pkg="lgr" data-topic="AppenderMemory" data-id="set_should_flush"><a href='../../lgr/html/AppenderMemory.html#method-AppenderMemory-set_should_flush'><code>lgr::AppenderMemory$set_should_flush()</code></a></span></li>
<li><span class="pkg-link" data-pkg="lgr" data-topic="AppenderMemory" data-id="show"><a href='../../lgr/html/AppenderMemory.html#method-AppenderMemory-show'><code>lgr::AppenderMemory$show()</code></a></span></li>
</ul>
</details>
}}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-AppenderRedis-new"></a>}}
\if{latex}{\out{\hypertarget{method-AppenderRedis-new}{}}}
\subsection{Method \code{new()}}{
Creates a new instance of this \link[R6:R6Class]{R6} class.
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{AppenderRedis$new(
  config,
  key,
  threshold = NA_integer_,
  layout = lgr::LayoutJson$new(timestamp_fmt = "\%Y-\%m-\%d \%H:\%M:\%OS3"),
  buffer_size = 0,
  flush_threshold = "error",
  flush_on_exit = TRUE,
  flush_on_rotate = TRUE,
  should_flush = NULL,
  filters = NULL
)}\if{html}{\out{</div>}}
}

\subsection{Arguments}{
\if{html}{\out{<div class="arguments">}}
\describe{
\item{\code{config}}{(\link[redux:redis_config]{redux::redis_config})\cr
Redis configuration options.}

\item{\code{key}}{(\code{character(1)})\cr
Key of the list holding the log messages in the Redis data store.}

\item{\code{threshold}}{(\code{integer(1)} | \code{character(1)})\cr
Threshold for the log messages.}

\item{\code{layout}}{(\link[lgr:Layout]{lgr::Layout})\cr
Layout for the log messages.}

\item{\code{buffer_size}}{(\code{integer(1)})\cr
Size of the buffer.}

\item{\code{flush_threshold}}{(\code{character(1)})\cr
Threshold for flushing the buffer.}

\item{\code{flush_on_exit}}{(\code{logical(1)})\cr
Flush the buffer on exit.}

\item{\code{flush_on_rotate}}{(\code{logical(1)})\cr
Flush the buffer on rotate.}

\item{\code{should_flush}}{(\code{function})\cr
Function that determines if the buffer should be flushed.}

\item{\code{filters}}{(\code{list})\cr
List of filters.}
}
\if{html}{\out{</div>}}
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-AppenderRedis-flush"></a>}}
\if{latex}{\out{\hypertarget{method-AppenderRedis-flush}{}}}
\subsection{Method \code{flush()}}{
Sends the buffer's contents to the Redis data store, and then clears the buffer.
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{AppenderRedis$flush()}\if{html}{\out{</div>}}
}

}
}
