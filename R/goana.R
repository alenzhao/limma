goana <- function(de,...) UseMethod("goana")

goana.MArrayLM <- function(de, coef = ncol(de), geneid = rownames(de), FDR = 0.05, trend = FALSE, ...)
#	Gene ontology analysis of DE genes from linear model fit
#	Gordon Smyth and Yifang Hu
#	Created 20 June 2014.  Last modified 1 May 2015.
{
#	Avoid argument collision with default method
	dots <- names(list(...))
	if("universe" %in% dots) stop("goana.MArrayLM defines its own universe",call.=FALSE)
	if((!is.logical(trend) || trend) && "covariate" %in% dots) stop("goana.MArrayLM defines it own covariate",call.=FALSE)

#	Check fit
	if(is.null(de$coefficients)) stop("de does not appear to be a valid MArrayLM fit object.")
	if(is.null(de$p.value)) stop("p.value not found in fit object, perhaps need to run eBayes first.")	
	if(length(coef) != 1) stop("Only one coef can be specified.")
	ngenes <- nrow(de)

#	Check geneid
#	Can be either a vector of gene IDs or an annotation column name
	geneid <- as.character(geneid)
	if(length(geneid) == ngenes) {
		universe <- geneid
	} else {
		if(length(geneid) == 1L) {
			universe <- de$genes[[geneid]]
			if(is.null(universe)) stop("Column ",geneid," not found in de$genes")
		} else
			stop("geneid of incorrect length")
	}

#	Check trend
#	Can be logical, or a numeric vector of covariate values, or the name of the column containing the covariate values
	if(is.logical(trend)) {
		if(trend) {
			covariate <- de$Amean
			if(is.null(covariate)) stop("Amean not found in fit")
		}
	} else {
		if(is.numeric(trend)) {
			if(length(trend) != ngenes) stop("If trend is numeric, then length must equal nrow(de)")
			covariate <- trend
			trend <- TRUE
		} else {
			if(is.character(trend)) {
				if(length(trend) != 1L) stop("If trend is character, then length must be 1")
				covariate <- de$genes[[trend]]
				if(is.null(covariate)) stop("Column ",trend," not found in de$genes")
				trend <- TRUE
			} else
				stop("trend is neither logical, numeric nor character")
		}
	}

#	Check FDR
	if(!is.numeric(FDR) | length(FDR) != 1) stop("FDR must be numeric and of length 1.")
	if(FDR < 0 | FDR > 1) stop("FDR should be between 0 and 1.")

#	Get up and down DE genes
	fdr.coef <- p.adjust(de$p.value[,coef], method = "BH")
	EG.DE.UP <- universe[fdr.coef < FDR & de$coef[,coef] > 0]
	EG.DE.DN <- universe[fdr.coef < FDR & de$coef[,coef] < 0]
	DEGenes <- list(Up=EG.DE.UP, Down=EG.DE.DN)

#	If no DE genes, return data.frame with 0 rows
	if(length(EG.DE.UP)==0 && length(EG.DE.DN)==0) {
		message("No DE genes")
		return(data.frame())
	}

	if(trend)
		goana(de=DEGenes, universe = universe, covariate=covariate, ...)
	else
		goana(de=DEGenes, universe = universe, ...)
}

goana.default <- function(de, universe = NULL, species = "Hs", prior.prob = NULL, covariate=NULL, plot=FALSE, ...)
#	Gene ontology analysis of DE genes
#	Gordon Smyth and Yifang Hu
#	Created 20 June 2014.  Last modified 23 June 2016.
{
#	Ensure de is a list
	if(!is.list(de)) de <- list(DE = de)

#	Stop if components of de are not vectors
	if(!all(vapply(de,is.vector,TRUE))) stop("components of de should be vectors")

#	Ensure gene IDs are of character mode
	de <- lapply(de, as.character)
	if(!is.null(universe)) universe <- as.character(universe)

#	Ensure all gene sets have unique names
	nsets <- length(de)
	names(de) <- trimWhiteSpace(names(de))
	NAME <- names(de)
	i <- which(NAME == "" | is.na(NAME))
	NAME[i] <- paste0("DE",i)
	names(de) <- makeUnique(NAME)

#	Fit trend in DE with respect to the covariate, combining all de lists
	if(!is.null(covariate)) {
		covariate <- as.numeric(covariate)
		if(length(covariate) != length(covariate)) stop("universe and covariate must have same length")
		isDE <- as.numeric(universe %in% unlist(de))
		o <- order(covariate)
		prior.prob <- covariate
		span <- approx(x=c(20,200),y=c(1,0.5),xout=sum(isDE),rule=2)$y
		prior.prob[o] <- tricubeMovingAverage(isDE[o],span=span)
		if(plot) barcodeplot(covariate, index=(isDE==1), worm=TRUE, span.worm=span)
	}

#	Get access to package of GO terms
	suppressPackageStartupMessages(OK <- requireNamespace("GO.db",quietly=TRUE))
	if(!OK) stop("GO.db package required but not installed (or can't be loaded)")

#	Get access to required annotation functions
	suppressPackageStartupMessages(OK <- requireNamespace("AnnotationDbi",quietly=TRUE))
	if(!OK) stop("AnnotationDbi package required but not installed (or can't be loaded)")

#	Load appropriate organism package
	orgPkg <- paste0("org.",species,".eg.db")
	suppressPackageStartupMessages(OK <- requireNamespace(orgPkg,quietly=TRUE))
	if(!OK) stop(orgPkg," package required but not not installed (or can't be loaded)")

#	Get GO to Entrez Gene mappings
	obj <- paste0("org.",species,".egGO2ALLEGS")
	egGO2ALLEGS <- tryCatch(getFromNamespace(obj,orgPkg), error=function(e) FALSE)
	if(is.logical(egGO2ALLEGS)) stop("Can't find gene ontology mappings in package ",orgPkg)

#	Convert gene-GOterm mappings to data.frame and remove duplicate entries
	if(is.null(universe)) {
		EG.GO <- AnnotationDbi::toTable(egGO2ALLEGS)
		d <- duplicated(EG.GO[,c("gene_id", "go_id", "Ontology")])
		EG.GO <- EG.GO[!d, ]
		universe <- unique(EG.GO$gene_id)
		universe <- as.character(universe)
	} else {

		universe <- as.character(universe)

		dup <- duplicated(universe)
		if(!is.null(prior.prob)) {
			if(length(prior.prob)!=length(universe)) stop("length(prior.prob) must equal length(universe)")
			prior.prob <- rowsum(prior.prob,group=universe,reorder=FALSE)
			n <- rowsum(rep_len(1L,length(universe)),group=universe,reorder=FALSE)
			prior.prob <- prior.prob/n
		}
		universe <- universe[!dup]

		m <- match(AnnotationDbi::Lkeys(egGO2ALLEGS),universe,0L)
		universe <- universe[m]
		if(!is.null(prior.prob)) prior.prob <- prior.prob[m]

		AnnotationDbi::Lkeys(egGO2ALLEGS) <- universe
		EG.GO <- AnnotationDbi::toTable(egGO2ALLEGS)
		d <- duplicated(EG.GO[,c("gene_id", "go_id", "Ontology")])
		EG.GO <- EG.GO[!d, ]
	}

	Total <- length(unique(EG.GO$gene_id))
	if(Total<1L) stop("No genes found in universe")

#	Check prior probabilities
	if(!is.null(prior.prob)) {
		if(length(prior.prob)!=length(universe)) stop("length(prior.prob) must equal length(universe)")
	}

#	Overlap with DE genes
	isDE <- lapply(de, function(x) EG.GO$gene_id %in% x)
	TotalDE <- lapply(isDE, function(x) length(unique(EG.GO$gene_id[x])))
	nDE <- length(isDE)

	if(length(prior.prob)) {
	#	Probability weight for each gene
		m <- match(EG.GO$gene_id, universe)
		PW2 <- list(prior.prob[m])
		X <- do.call(cbind, c(N=1, isDE, PW=PW2))
	} else
		X <- do.call(cbind, c(N=1, isDE))

	group <- paste(EG.GO$go_id, EG.GO$Ontology, sep=".")
	S <- rowsum(X, group=group, reorder=FALSE)

	P <- matrix(0, nrow = nrow(S), ncol = nsets)

	if(length(prior.prob)) {

#		Calculate average prior prob for each set
		PW.ALL <- sum(prior.prob[universe %in% EG.GO$gene_id])
		AVE.PW <- S[,"PW"]/S[,"N"]
		W <- AVE.PW*(Total-S[,"N"])/(PW.ALL-S[,"N"]*AVE.PW)

#		Wallenius' noncentral hypergeometric test
		if(!requireNamespace("BiasedUrn",quietly=TRUE)) stop("BiasedUrn package required but is not installed (or can't be loaded)")
		for(j in 1:nsets) for(i in 1:nrow(S)) 
			P[i,j] <- BiasedUrn::pWNCHypergeo(S[i,1+j], S[i,"N"], Total-S[i,"N"], TotalDE[[j]], W[i],lower.tail=FALSE) + BiasedUrn::dWNCHypergeo(S[i,1+j], S[i,"N"], Total-S[i,"N"], TotalDE[[j]], W[i])
		S <- S[,-ncol(S)]

	} else {

	#	Fisher's exact test
		for(j in 1:nsets)
			P[,j] <- phyper(q=S[,1+j]-0.5,m=TotalDE[[j]],n=Total-TotalDE[[j]], k=S[,"N"],lower.tail=FALSE)

	}

#	Assemble output
	g <- strsplit2(rownames(S),split="\\.")
	TERM <- suppressMessages(AnnotationDbi::select(GO.db::GO.db,keys=g[,1],columns="TERM"))
	Results <- data.frame(Term = TERM[[2]], Ont = g[,2], S, P, stringsAsFactors=FALSE)
	rownames(Results) <- g[,1]

#	Name p-value columns
	colnames(Results)[3+nsets+(1L:nsets)] <- paste0("P.", names(de))

	Results
}

topGO <- function(results, ontology = c("BP", "CC", "MF"), sort = NULL, number = 20L, truncate.term=NULL)
#	Extract top GO terms from goana output 
#	Gordon Smyth and Yifang Hu
#	Created 20 June 2014. Last modified 23 June 2016.
{
#	Check results
	if(!is.data.frame(results)) stop("results should be a data.frame.")

#	Check ontology
	ontology <- match.arg(unique(ontology), c("BP", "CC", "MF"), several.ok = TRUE)

#	Limit results to specified ontologies
	if(length(ontology) < 3L) {
		sel <- results$Ont %in% ontology
		results <- results[sel,]
	}
	dimres <- dim(results)

#	Check number
	if(!is.numeric(number)) stop("number should be a positive integer")
	if(number > dimres[1L]) number <- dimres[1]
	if(number < 1L) return(results[integer(0),])

#	Number of gene lists for which results are reported
#	Lists are either called "Up" and "Down" or have user-supplied names
	nsets <- (dimres[2L]-3L) %/% 2L
	if(nsets < 1L) stop("results has wrong number of columns")
	setnames <- colnames(results)[4L:(3L+nsets)]

#	Check sort. Defaults to all gene lists.
	if(is.null(sort)) {
		isort <- 1L:nsets
	} else {
		sort <- as.character(sort)
		isort <- which(tolower(setnames) %in% tolower(sort))
		if(!length(isort)) stop("sort column not found in results")
	}

#	Sort by minimum p-value for specified gene lists
	P.col <- 3L+nsets+isort
	if(length(P.col)==1L) {
		P <- results[,P.col]
	} else {
		P <- do.call("pmin",as.data.frame(results[,P.col,drop=FALSE]))
	}
	o <- order(P,results$N,results$Term)
	tab <- results[o[1L:number],,drop=FALSE]

#	Truncate Term column for readability
	if(!is.null(truncate.term)) {
		truncate.term <- as.integer(truncate.term[1])
		truncate.term <- max(truncate.term,5L)
		truncate.term <- min(truncate.term,1000L)
		tm2 <- truncate.term-3L
		i <- (nchar(tab$Term) > tm2)
		tab$Term[i] <- paste0(substring(tab$Term[i],1L,tm2),"...")
	}

	tab
}
