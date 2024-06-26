% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/helper.R
\name{get_hostname}
\alias{get_hostname}
\title{Get the computer name of the current host}
\usage{
get_hostname()
}
\value{
\code{character(1)} of hostname.
}
\description{
Returns the computer name of the current host.
First it tries to get the computer name from the environment variables \code{HOST}, \code{HOSTNAME} or \code{COMPUTERNAME}.
If this fails it tries to get the computer name from the function \code{Sys.info()}.
Finally, if this fails it queries the computer name from the command \code{uname -n}.
Copied from the \code{R.utils} package.
}
\examples{
get_hostname()
}
\keyword{internal}
