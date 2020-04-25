
#library(parallel); numCores <- 44
library(dada2);to 
path <- "/tmp/fastq" # CHANGE ME to the directory containing the fastq files after unzipping.
list.files(path)

# Forward and reverse fastq filenames have format: SAMPLENAME_R1_001.fastq and SAMPLENAME_R2_001.fastq
fnFs <- sort(list.files(path, pattern="_R1_001.fastq", full.names = TRUE))
fnRs <- sort(list.files(path, pattern="_R2_001.fastq", full.names = TRUE))
# Extract sample names, assuming filenames have format: SAMPLENAME_XXX.fastq
sample.names <- sapply(strsplit(basename(fnFs), "_"), `[`, 1)

pq1 <- plotQualityProfile(fnFs[1:2])


pq2 <- plotQualityProfile(fnRs[1:2])


# Place filtered files in filtered/ subdirectory
filtFs <- file.path(path, "filtered", paste0(sample.names, "_F_filt.fastq.gz"))
filtRs <- file.path(path, "filtered", paste0(sample.names, "_R_filt.fastq.gz"))
names(filtFs) <- sample.names
names(filtRs) <- sample.names
save.image()


out <- filterAndTrim(fnFs, filtFs, fnRs, filtRs, truncLen=c(240,240), trimLeft=c(17,21), maxN=0, maxEE=c(5,5), truncQ=2, rm.phix=TRUE,
              compress=TRUE, multithread=40) # On Windows set multithread=FALSE
out
save.image()

errF <- learnErrors(filtFs, multithread=40)
save.image()

errR <- learnErrors(filtRs, multithread=40)
save.image()

plot_error <- plotErrors(errF, nominalQ=TRUE)


dadaFs <- dada(filtFs, err=errF, multithread=40)
save.image()

dadaRs <- dada(filtRs, err=errR, multithread=40)
save.image()
dadaFs[[1]]


mergers <- mergePairs(dadaFs, filtFs, dadaRs, filtRs, verbose=TRUE)
# Inspect the merger data.frame from the first sample
head(mergers[[1]])
save.image()
seqtab <- makeSequenceTable(mergers)
dim(seqtab)
save.image()
seqtab.nochim <- removeBimeraDenovo(seqtab, method="consensus", multithread=40, verbose=TRUE)
dim(seqtab.nochim)
save.image()
sum(seqtab.nochim)/sum(seqtab)
save.image()

getN <- function(x) sum(getUniques(x))
track <- cbind(out, sapply(dadaFs, getN), sapply(dadaRs, getN), sapply(mergers, getN), rowSums(seqtab.nochim))
#single samples######  track <- cbind(out, getN(dadaFs), getN(dadaRs), getN(mergers), rowSums(seqtab.nochim))
# If processing a single sample, remove the sapply calls: e.g. replace sapply(dadaFs, getN) with getN(dadaFs)
save.image()
colnames(track) <- c("input", "filtered", "denoisedF", "denoisedR", "merged", "nonchim")
rownames(track) <- sample.names
head(track)
save.image()
taxa <- assignTaxonomy(seqtab.nochim, "/tmp/fastq/silva_nr_v138_train_set.fa.gz",multithread=40)
taxa2 <- assignSpecies(seqtab.nochim, "/tmp/fastq/silva_species_assignment_v138.fa.gz")

taxa.print <- taxa # Removing sequence rownames for display only
rownames(taxa.print) <- NULL
head(taxa.print)


taxa.print2 <- taxa2 # Removing sequence rownames for display only
rownames(taxa.print2) <- NULL
head(taxa.print2)

save.image()

library(phyloseq); packageVersion("phyloseq")
library(Biostrings); packageVersion("Biostrings")
library(ggplot2); packageVersion("ggplot2")


theme_set(theme_bw())

  # giving our seq headers more manageable names (ASV_1, ASV_2...)
asv_seqs <- colnames(seqtab.nochim)
asv_headers <- vector(dim(seqtab.nochim)[2], mode="character")

for (i in 1:dim(seqtab.nochim)[2]) {
  asv_headers[i] <- paste(">ASV", i, sep="_")
}

  # making and writing out a fasta of our final ASV seqs:
asv_fasta <- c(rbind(asv_headers, asv_seqs))
write(asv_fasta, "ASVs.fa")

  # count table:
asv_tab <- t(seqtab.nochim)
row.names(asv_tab) <- sub(">", "", asv_headers)
write.table(asv_tab, "ASVs_counts.tsv", sep="\t", quote=F, col.names=NA)

  # tax table:
asv_tax <- taxa
row.names(asv_tax) <- sub(">", "", asv_headers)
write.table(asv_tax, "ASVs_taxonomy.tsv", sep="\t", quote=F, col.names=NA)
