#' Gene set enrichment for clusters
#' 
#' Gene set enrichment for clusters sourced from coExp function. the enrichment
#' score are based on -log(p) with p from hyper-geometric test.
#' 
#' @param genecl_obj a genecl object
#' @param annofile gene set annotation file
#' @param sampleLabel sameple Label
#' @param TermFreq a value from [0,1) to filter low-frequence gene sets
#' @param ncore the number of cores used
#' 
#' @return a list containing the enrichment score for each clustering methods 
#' and cluster numbers included in the genecl_obj
#' @import parallel
#' @import foreach
#' @import doParallel
#' @examples 
#' 
#' #annotaion
#' annoGMT <- "c2.cp.kegg.v5.0.symbols.gmt"
#' annofile <- system.file("extdata", annoGMT, package="cogena")
#' 
#' data(PD)
#' clMethods <- c("hierarchical","kmeans","diana","fanny","som","model","sota","pam","clara","agnes")
#' genecl_result <- coExp(DEexprs, nClust=2:3, clMethods=c("hierarchical","kmeans"), 
#'     metric="correlation", method="complete", ncore=2, verbose=TRUE)
#' 
#' clen_res <- clEnrich(genecl_result, annofile=annofile, sampleLabel=sampleLabel)
#'     
#' @export
#' 
clEnrich <- function(genecl_obj, annofile=NULL, sampleLabel=NULL, TermFreq=0, ncore=1){
    
    ############################################################################
    # Annotation data
    if (is.null(annofile)) {
        annofile <- system.file("extdata", "c2.cp.kegg.v5.0.symbols.gmt", 
                                package="cogena")
    }
    annotation <- gene2set(annofile, genecl_obj@labels, TermFreq=TermFreq)
    # the background gene gene-sets matrix
    AllGeneSymbols=NULL
    data(AllGeneSymbols, envir = environment())
    annotationGenesPop <- gene2set(annofile, AllGeneSymbols, TermFreq=TermFreq)
    annotationGenesPop <- annotationGenesPop[,colnames(annotation)]
    
    if (ncol(annotationGenesPop) ==0 || ncol(annotation)==0) {
        stop("Error in annotation as ncol equals zero. 
        Maybe lower the TermFreq value.")
    }
    
    
    ############################################################################
    ############################################################################
    clen <- list()
    
    # Enrichment of the All DE genes
    All <- PEI(genecl_obj@labels, annotation=annotation, 
               annotationGenesPop=annotationGenesPop)
    
    cl <- parallel::makeCluster(ncore)
    doParallel::registerDoParallel(cl)
    nc <- NULL
    ############################################################################
    # Gene sets enrichment analysis for clusters
    for (i in clusterMethods(genecl_obj) ) {
        pei_tmp <- foreach::foreach (nc = as.character(nClusters(genecl_obj)) ) %dopar% {
            cluster <- cogena::geneclusters(genecl_obj, i, nc)
            if (nc != length(unique(cluster))) {
                # warning (paste("Cluster", nc, "(aim) only have", length(unique(cluster)), "(result) clusters"))
                pei <- NA
            } else {
                pei <- matrix(NA, nrow=length(unique(cluster)), 
                              ncol=ncol(annotation))
                rownames(pei) <- sort(unique(cluster))
                colnames(pei) <- colnames(annotation)
                for (k in  sort(unique(cluster))) {
                    genenames <- names(which(cluster==k))
                    pei[as.character(k),] <- cogena::PEI(genenames, annotation=annotation, 
                                                 annotationGenesPop=annotationGenesPop)
                }
                pei <- rbind(pei, All)
                # negative log p value
                logAdjPEI <- function (pei) {
                    # fdr based on pval
                    pei.adjust <- matrix(p.adjust(pei, "fdr"), ncol=ncol(pei))
                    dimnames(pei.adjust) <- dimnames(pei)
                    pei.NeglogPval <- -log(pei.adjust)
                }
                pei <- logAdjPEI(pei)
            }
            return (pei)
        }
        names(pei_tmp) <- nClusters(genecl_obj)
        clen[[i]] <- pei_tmp
    }
    
    # stopImplicitCluster()
    parallel::stopCluster(cl)
    
    ############################################################################
    ############################################################################
    res <- new("cogena", 
               mat=genecl_obj@mat, 
               measures=clen, 
               Distmat=genecl_obj@Distmat, 
               clusterObjs=genecl_obj@clusterObjs, 
               clMethods=genecl_obj@clMethods, 
               labels=genecl_obj@labels, 
               annotation=annotation,
               sampleLabel=as.factor(sampleLabel),
               nClust=genecl_obj@nClust, 
               metric=genecl_obj@metric, 
               method=genecl_obj@method, 
               ncore=ncore,
               gmt=basename(annofile),
               call=match.call() )
    return (res)
}

