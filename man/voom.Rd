\name{voom}
\alias{voom}
\title{Transform RNA-Seq Data Ready for Linear Modelling}
\description{
Transform count data to log2-counts per million (logCPM), estimate the mean-variance relationship and use this to compute appropriate observational-level weights.
The data are then ready for linear modelling.
}

\usage{
voom(counts, design = NULL, lib.size = NULL, normalize.method = "none",
     span = 0.5, plot = FALSE, save.plot = FALSE, \dots)
}
\arguments{
 \item{counts}{a numeric \code{matrix} containing raw counts, or an \code{ExpressionSet} containing raw counts, or a \code{DGEList} object.}
 \item{design}{design matrix with rows corresponding to samples and columns to coefficients to be estimated.  Defaults to the unit vector meaning that samples are treated as replicates.}
 \item{lib.size}{numeric vector containing total library sizes for each sample.
 If \code{NULL} and \code{counts} is a \code{DGEList} then, the normalized library sizes are taken from \code{counts}.
 Otherwise library sizes are calculated from the columnwise counts totals.}
 \item{normalize.method}{normalization method to be applied to the logCPM values.
 Choices are as for the \code{method} argument of \code{normalizeBetweenArrays} when the data is single-channel.}
 \item{span}{width of the lowess smoothing window as a proportion.}
 \item{plot}{logical, should a plot of the mean-variance trend be displayed?}
 \item{save.plot}{logical, should the coordinates and line of the plot be saved in the output?}
 \item{\dots}{other arguments are passed to \code{lmFit}.}
  }

\details{
This function is intended to process RNA-Seq or ChIP-Seq data prior to linear modelling in limma.

\code{voom} is an acronym for mean-variance modelling at the observational level.
The key concern is to estimate the mean-variance relationship in the data, then use this to compute appropriate weights for each observation.
Count data almost show non-trivial mean-variance relationships.
Raw counts show increasing variance with increasing count size, while log-counts typically show a decreasing mean-variance trend.
This function estimates the mean-variance trend for log-counts, then assigns a weight to each observation based on its predicted variance.
The weights are then used in the linear modelling process to adjust for heteroscedasticity. 

In an experiment, a count value is observed for each tag in each sample. A tag-wise mean-variance trend is computed using \code{\link{lowess}}. The tag-wise mean is the mean log2 count with an offset of 0.5, across samples for a given tag. The tag-wise variance is the quarter-root-variance of normalized log2 counts per million values with an offset of 0.5, across samples for a given tag. Tags with zero counts across all samples are not included in the lowess fit.
Optional normalization is performed using \code{\link{normalizeBetweenArrays}}. 
Using fitted values of log2 counts from a linear model fit by \code{\link{lmFit}}, variances from the mean-variance trend were interpolated for each observation. This was carried out by \code{\link{approxfun}}. Inverse variance weights can be used to correct for mean-variance trend in the count data.
}
\value{
An \code{\link[limma:EList]{EList}} object with the following components:
\item{E}{numeric matrix of normalized expression values on the log2 scale}
\item{weights}{numeric matrix of inverse variance weights}
\item{design}{design matrix}
\item{lib.size}{numeric vector of total normalized library sizes}
\item{genes}{dataframe of gene annotation extracted from \code{counts}}
\item{voom.xy}{if \code{save.plot}, list containing x and y coordinates for points in mean-variance plot}
\item{voom.line}{if \code{save.plot}, list containing coordinates of loess line in the mean-variance plot}
 }

\author{Charity Law and Gordon Smyth}

\references{
Law, CW, Chen, Y, Shi, W, Smyth, GK (2014).
Voom: precision weights unlock linear model analysis tools for RNA-seq read counts.
\emph{Genome Biology} 15, R29.
\url{http://genomebiology.com/2014/15/2/R29}
}

\seealso{
\code{\link{voomWithQualityWeights}}.
\code{\link{vooma}} is similar to \code{voom} but for microarrays instead of RNA-seq.

A summary of functions for RNA-seq analysis is given in \link{11.RNAseq}.
}

\keyword{rna-seq}
