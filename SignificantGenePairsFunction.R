SignificantGenePairs <- function(InputFileName,PercentileCutOff,highORlow)
{
  library(data.table)
  df <- fread(InputFileName)
  colnames(df) <- c("Gene.ID",colnames(df)[-1])
  Non.Zero.Genes <- as.character(df$Gene.ID)
  Exprs.Matrix <- as.matrix(df[,-1])
  Sample.IDs <- gsub(".","-",colnames(df)[-1],fixed = T)
  CutOffPerc <- PercentileCutOff/100
  
  rm(df)
  
  #Matrix that contains the order of the samples in increasing order of expression for all genes
  Sample.Order.Increasing.Matrix <- t(apply(Exprs.Matrix,1,order))
  
  #Find gene-pairs with significant overlaps between their percentile sets
  if (highORlow == "h" | highORlow == "H" | highORlow == "high" | highORlow == "High") {
    Start.Index <- ncol(Exprs.Matrix) - (ceiling(CutOffPerc*ncol(Exprs.Matrix))) +1
    
    #Ser.Nos of Non-Zero Samples per gene
    List.of.Ser.Nos.of.Non.Zero.Samples <- vector(mode = "list",length = length(Non.Zero.Genes))
    for (i in 1:length(Non.Zero.Genes))
    {
      List.of.Ser.Nos.of.Non.Zero.Samples[[i]] <- as.numeric(which(Exprs.Matrix[i,] !=0))
    }
    
    Lengths.Non.Zero.Samples <- unlist(lapply(List.of.Ser.Nos.of.Non.Zero.Samples,length))
    
    #Find the genes with less than cutoff perc non-zero samples
    Genes.With.Less.Samples <- which(Lengths.Non.Zero.Samples < length(Sample.IDs))
    
    #List of outlier samples for every gene
    List.OutlierSamples <- vector(mode="list")
    for (i in 1:length(Non.Zero.Genes))
    {
      List.OutlierSamples[[i]] <- Sample.IDs[Sample.Order.Increasing.Matrix[i,Start.Index:ncol(Exprs.Matrix)]]
    }
    
    if (length(Genes.With.Less.Samples) !=0) {
      for (i in 1:length(Genes.With.Less.Samples))
      {
        TempI <- Genes.With.Less.Samples[i]
        if (Lengths.Non.Zero.Samples[TempI] < ceiling(CutOffPerc*ncol(Exprs.Matrix))) {
          List.OutlierSamples[[TempI]] <- Sample.IDs[which(Exprs.Matrix[TempI,] !=0)]
        }
      }
    }
    
    List.OutlierSamples.SerNos <- vector(mode="list")
    for (i in 1:length(Non.Zero.Genes))
    {
      List.OutlierSamples.SerNos[[i]] <- Sample.Order.Increasing.Matrix[i,Start.Index:ncol(Exprs.Matrix)]
    }
    
    if (length(Genes.With.Less.Samples) !=0) {
      for (i in 1:length(Genes.With.Less.Samples))
      {
        TempI <- Genes.With.Less.Samples[i]
        if (Lengths.Non.Zero.Samples[TempI] < ceiling(CutOffPerc*ncol(Exprs.Matrix))) {
          List.OutlierSamples.SerNos[[TempI]] <- which(Exprs.Matrix[TempI,] !=0)
        }
      }
    }
    
    #Binary matrix with 1 for samples that are in the percentile set for any given gene
    Binary.Matrix.For.Genes.Outliers <- matrix(0,nrow = length(Non.Zero.Genes),ncol = length(Sample.IDs))
    
    for (i in 1:nrow(Binary.Matrix.For.Genes.Outliers))
    {
      Binary.Matrix.For.Genes.Outliers[i,List.OutlierSamples.SerNos[[i]]] <- 1
    }
    
    Genes.Samples.Binary.df <- data.frame(Non.Zero.Genes,Binary.Matrix.For.Genes.Outliers)
    colnames(Genes.Samples.Binary.df) <- c("Gene.ID",Sample.IDs)
    
    File.Name <- as.character(paste(gsub(".csv","",InputFileName),"_H",as.character(CutOffPerc),"_Genes_Samples_BinaryMatrix.csv",sep = ""))
    
    write.table(Genes.Samples.Binary.df,file = File.Name,row.names = F,col.names = T,sep = ",")
    
    rm(Genes.Samples.Binary.df)
    
    #Outlier overlaps matrix
    SampleOverlaps.Matrix <- matrix(0,nrow = length(Non.Zero.Genes),ncol = length(Non.Zero.Genes))
    SampleOverlaps.Matrix <- Binary.Matrix.For.Genes.Outliers %*% t(Binary.Matrix.For.Genes.Outliers)
    SampleOverlaps.Matrix[lower.tri(SampleOverlaps.Matrix,diag = T)] <- -1
    
    rm(Sample.Order.Increasing.Matrix)
    
    #Hypergeometric test for overlaps (with alternative hypothesis that overlap is greater)
    
    Temp.Overlaps.Vec <- seq(0,ceiling(CutOffPerc*length(Sample.IDs)))
    
    p.val.Overlaps <- vector(mode = "numeric",length = length(Temp.Overlaps.Vec))
    for (i in 1:length(Temp.Overlaps.Vec))
    {
      t <- Temp.Overlaps.Vec[i]
      n <- length(Sample.IDs)
      a <- ceiling(CutOffPerc*length(Sample.IDs)) 
      b <- ceiling(CutOffPerc*length(Sample.IDs)) 
      p.val.Overlaps[i] <- sum(dhyper(t:b,a,n-a,b))
    }
    
    #p-val overlaps for all pairs
    p.values.Overlaps.Matrix <- matrix(-1,nrow = nrow(SampleOverlaps.Matrix),ncol = ncol(SampleOverlaps.Matrix))
    for (i in 1:length(Temp.Overlaps.Vec))
    {
      call <- cbind(which(SampleOverlaps.Matrix == Temp.Overlaps.Vec[i],arr.ind = T)[,1],which(SampleOverlaps.Matrix == Temp.Overlaps.Vec[i],arr.ind = T)[,2])
      p.values.Overlaps.Matrix[call] <- p.val.Overlaps[i]
    }
    
    #p-vals for special cases
    if (length(Genes.With.Less.Samples) != 0) {
      Temp.Overlaps.Vec <- seq(0,ceiling(CutOffPerc*length(Sample.IDs)))
      
      p.values.List.More.Zeros <- vector(mode = "list",length = length(Genes.With.Less.Samples))
      for (i in 1:length(p.values.List.More.Zeros))
      {
        p.val.Overlaps.Temp <- rep(1,length = length(Temp.Overlaps.Vec))
        TempI <- Genes.With.Less.Samples[i]
        for (j in 1:length(Temp.Overlaps.Vec))
        {
          
          t <- Temp.Overlaps.Vec[j]
          n <- Lengths.Non.Zero.Samples[TempI]
          
          a1 <- ceiling(CutOffPerc*length(Sample.IDs))
          
          if (a1 > n) {
            a <- n
          } else {
            a <- a1
          }
          
          b1 <- length(List.OutlierSamples.SerNos[[TempI]]) 
          b2 <- ceiling(CutOffPerc*length(Sample.IDs))
          
          if (b1 < b2) {
            b <- b1
          } else {
            b <- b2
          }
          
          p.val.Overlaps.Temp[j] <- sum(dhyper(t:b,a,n-a,b))
        }
        p.values.List.More.Zeros[[i]] <- p.val.Overlaps.Temp
      }
      
      
      for (i in 1:length(Genes.With.Less.Samples))
      {
        TempI <- Genes.With.Less.Samples[i]
        p.val.Overlaps.Row.Temp <- p.values.Overlaps.Matrix[TempI,]
        p.val.Overlaps.Column.Temp <- p.values.Overlaps.Matrix[,TempI]
        for (j in 1:length(Temp.Overlaps.Vec))
        {
          if (length(which(SampleOverlaps.Matrix[TempI,] == Temp.Overlaps.Vec[j])) !=0) {
            p.val.Overlaps.Row.Temp[which(SampleOverlaps.Matrix[TempI,] == Temp.Overlaps.Vec[j])] <- p.values.List.More.Zeros[[i]][j]
          }
          if (length(which(SampleOverlaps.Matrix[,TempI] == Temp.Overlaps.Vec[j])) !=0) {
            p.val.Overlaps.Column.Temp[which(SampleOverlaps.Matrix[,TempI] == Temp.Overlaps.Vec[j])] <- p.values.List.More.Zeros[[i]][j]
          }
        }
        p.values.Overlaps.Matrix[TempI,] <- p.val.Overlaps.Row.Temp
        p.values.Overlaps.Matrix[,TempI] <- p.val.Overlaps.Column.Temp
      }
      
      Combn.Genes <- combn(Genes.With.Less.Samples,2)
      
      for (i in 1:ncol(Combn.Genes))
      {
        TempI <- Combn.Genes[1,i]
        TempJ <- Combn.Genes[2,i]
        
        Temp.Vec <- c(TempI,TempJ)
        Min.Ser.No <- which(c(Lengths.Non.Zero.Samples[TempI],Lengths.Non.Zero.Samples[TempJ]) == min(c(Lengths.Non.Zero.Samples[TempI],Lengths.Non.Zero.Samples[TempJ])))[1]
        
        t <- SampleOverlaps.Matrix[TempI,TempJ]
        
        n <- length(List.of.Ser.Nos.of.Non.Zero.Samples[[Temp.Vec[Min.Ser.No]]])
        
        a1 <- length(List.of.Ser.Nos.of.Non.Zero.Samples[[Temp.Vec[Min.Ser.No]]])
        a2 <- ceiling(CutOffPerc*length(Sample.IDs))
        
        if (a1 < a2) {
          a <- a1
        } else if (a1 >= a2 & a2 < n) {
          a <- a2
        } else {
          a <- n
        }
        
        b1 <- length(List.of.Ser.Nos.of.Non.Zero.Samples[[Temp.Vec[Min.Ser.No]]])
        b2 <- ceiling(CutOffPerc*length(Sample.IDs))
        if (b1 < b2) {
          b <- b1
        } else {
          b <- b2
        }
        
        p.values.Overlaps.Matrix[TempI,TempJ] <- sum(dhyper(t:b,a,n-a,b))
      }
    }
    
    p.values.Overlaps.Matrix[lower.tri(p.values.Overlaps.Matrix,diag = T)] <- -1
    
    rm(SampleOverlaps.Matrix)
    
    Non.Zero.Genes.Ser.Nos <- seq(1,length(Non.Zero.Genes))
    
    Col1.List <- vector(mode = "list",length = length(Non.Zero.Genes.Ser.Nos))
    Col2.List <- vector(mode = "list",length = length(Non.Zero.Genes.Ser.Nos))
    for (i in 1:length(Non.Zero.Genes.Ser.Nos))
    {
      if ((i-1) != 0) {
        Col2.List[[i]] <- rep(i,(i-1))
        Col1.List[[i]] <- seq(1,(i-1))
      }
    }
    
    Col1.Vec <- unlist(Col1.List)
    Col2.Vec <- unlist(Col2.List)
    
    rm(Col1.List)
    
    rm(Col2.List)
    
    p.val.Overlaps.Vec <- rep(1,length(Col1.Vec))
    
    p.val.Overlaps.Vec <- p.adjust(p.values.Overlaps.Matrix[upper.tri(p.values.Overlaps.Matrix)],method = "BH")
    
    rm(p.values.Overlaps.Matrix)
    
    Significant.Gene.Pairs <- which(p.val.Overlaps.Vec < 0.05)
    
    p.val.df <- data.frame(Col1.Vec[Significant.Gene.Pairs],Col2.Vec[Significant.Gene.Pairs],p.val.Overlaps.Vec[Significant.Gene.Pairs])
    
    colnames(p.val.df) <- c("Gene.1","Gene.2","p.val")
    
    File.Name <- as.character(paste(gsub(".csv","",InputFileName),"_H",as.character(CutOffPerc),"_SignificantGenePairs.csv",sep = ""))
    
    write.table(p.val.df,file = File.Name, row.names = F,col.names = T,sep = ",")
    
    #Code to generate plots
    
    if (length(p.val.df$p.val) > 1000000) {
      
      No.of.Edges <- vector(mode = "numeric")
      
      No.of.Genes <- vector(mode = "numeric")
      
      No.of.Samples <- vector(mode = "numeric")
      
      Exp.Power <- vector(mode = "numeric")
      
      No.of.Edges[1] <- 1
      
      Exp.Power[1] <- (min(p.val.df$p.val))
      
      k <- 1
      
      l <- 1
      
      while (No.of.Edges[l] < 1000000)
      {
        Relevant.Pairs <- which(p.val.df$p.val <= Exp.Power[k])
        No.of.Edges[k] <- length(Relevant.Pairs)
        No.of.Genes[k] <- length(union(p.val.df$Gene.1[Relevant.Pairs],p.val.df$Gene.2[Relevant.Pairs]))
        Samples.List.Relevant.Pairs <- vector(mode = "list",length = length(Relevant.Pairs))
        for (i in 1:length(Relevant.Pairs))
        {
          Samples.List.Relevant.Pairs[[i]] <- intersect(List.OutlierSamples.SerNos[[p.val.df$Gene.1[Relevant.Pairs[i]]]],List.OutlierSamples.SerNos[[p.val.df$Gene.2[Relevant.Pairs[i]]]])
        }
        No.of.Samples[k] <- length(unique(unlist(Samples.List.Relevant.Pairs)))
        
        k <- k+1
        Exp.Power[k] <- Exp.Power[k-1]*1000
        l <- k-1
      }
      
      Exp.Power <- Exp.Power[1:(k-1)]
      
      Genes.Per.Edge <- diff(No.of.Genes)/diff(No.of.Edges)
      
      Samples.Per.Edge <- diff(No.of.Samples)/diff(No.of.Edges)
      
      Diff.Genes <- diff(No.of.Genes)
      
      Diff.Samples <- diff(No.of.Samples)
      
      File.Name1 <- paste(gsub(".csv","",InputFileName),"_H",as.character(CutOffPerc),"_NoOfEdges.pdf",sep = "")
      pdf(File.Name1)
      plot(-log10(Exp.Power),No.of.Edges,xlab = "Significance of Overlap (-log10(p))",ylab = "Number of Edges in Graph",type = "o",col = "red",bg = "red",pch = 16)
      dev.off()
      
      File.Name2 <- paste(gsub(".csv","",InputFileName),"_H",as.character(CutOffPerc),"_GenesPerEdge.pdf",sep = "")
      pdf(File.Name2)
      plot(-log10(Exp.Power[2:(k-1)]),Genes.Per.Edge,xlab = "Significance of Overlap (-log10(p))",ylab = "Number of Genes Added/Number of Edges Added",type = "o",pch = 16,col = "red",bg = "red")
      dev.off()
      
      File.Name3 <- paste(gsub(".csv","",InputFileName),"_H",as.character(CutOffPerc),"_NoOfSamples.pdf",sep = "")
      pdf(File.Name3)
      plot(-log10(Exp.Power),No.of.Samples,xlab = "Significance of Overlap (-log10(p))",ylab = "Number of Samples",type = "o",pch = 16,col = "red",bg = "red")
      dev.off()
      
      File.Name4 <- paste(gsub(".csv","",InputFileName),"_H",as.character(CutOffPerc),"_SamplesPerEdge.pdf",sep = "")
      pdf(File.Name4)
      plot(-log10(Exp.Power[2:(k-1)]),Samples.Per.Edge,xlab = "Significance of Overlap (-log10(p))",ylab = "Number of Samples Added/Number of Edges Added",type = "o",pch = 16,col = "red",bg = "red")
      dev.off()
      
      File.Name5 <- paste(gsub(".csv","",InputFileName),"_H",as.character(CutOffPerc),"_GenesAdded.pdf",sep = "")
      pdf(File.Name5)
      plot(-log10(Exp.Power[2:(k-1)]),Diff.Genes,xlab = "Significance of Overlap (-log10(p))",ylab = "Number of Genes Added",type = "o",pch = 16,col = "red",bg = "red")
      dev.off()
      
      File.Name6 <- paste(gsub(".csv","",InputFileName),"_H",as.character(CutOffPerc),"_SamplesAdded.pdf",sep = "")
      pdf(File.Name6)
      plot(-log10(Exp.Power[2:(k-1)]),Diff.Samples,xlab = "Significance of Overlap (-log10(p))",ylab = "Number of Samples Added",type = "o",pch = 16,col = "red",bg = "red")
      dev.off()
      
    }
  } else if (highORlow == "l" | highORlow == "L" | highORlow == "low" | highORlow == "Low") {
    Start.Index <- 1
    
    #No of samples with zero expression value for each gene
    Lengths.Zero.Samples <- vector(mode = "numeric",length = length(Non.Zero.Genes))
    for (i in 1:length(Non.Zero.Genes))
    {
      Lengths.Zero.Samples[i] <- length(which(Exprs.Matrix[i,] ==0))
    }
    
    #Find the genes with more than PercCutOff zero samples
    
    Genes.With.More.Zero.Samples <- which(Lengths.Zero.Samples > ceiling(CutOffPerc*ncol(Exprs.Matrix)))
    
    #List of Low outlier Samples for every gene
    List.OutlierSamples <- vector(mode="list")
    for (i in 1:length(Non.Zero.Genes))
    {
      List.OutlierSamples[[i]] <- Sample.IDs[Sample.Order.Increasing.Matrix[i,Start.Index:ceiling(CutOffPerc*ncol(Exprs.Matrix))]]
    }
    
    if (length(Genes.With.More.Zero.Samples) != 0) {
      for (i in 1:length(Genes.With.More.Zero.Samples))
      {
        TempI <- Genes.With.More.Zero.Samples[i]
        List.OutlierSamples[[TempI]] <- Sample.IDs[which(Exprs.Matrix[TempI,] ==0)]
      }
    }
    
    List.OutlierSamples.SerNos <- vector(mode="list")
    for (i in 1:length(Non.Zero.Genes))
    {
      List.OutlierSamples.SerNos[[i]] <- Sample.Order.Increasing.Matrix[i,Start.Index:ceiling(CutOffPerc*ncol(Exprs.Matrix))]
    }
    
    if (length(Genes.With.More.Zero.Samples) != 0) {
      for (i in 1:length(Genes.With.More.Zero.Samples))
      {
        TempI <- Genes.With.More.Zero.Samples[i]
        List.OutlierSamples.SerNos[[TempI]] <- which(Exprs.Matrix[TempI,] ==0)
      }
    }
    
    #Binary matrix with 1 for samples that are in the percentile set for any given gene
    Binary.Matrix.For.Genes.Outliers <- matrix(0,nrow = length(Non.Zero.Genes),ncol = length(Sample.IDs))
    
    for (i in 1:nrow(Binary.Matrix.For.Genes.Outliers))
    {
      Binary.Matrix.For.Genes.Outliers[i,List.OutlierSamples.SerNos[[i]]] <- 1
    }
    
    Genes.Samples.Binary.df <- data.frame(Non.Zero.Genes,Binary.Matrix.For.Genes.Outliers)
    colnames(Genes.Samples.Binary.df) <- c("Gene.ID",Sample.IDs)
    
    File.Name <- as.character(paste(gsub(".csv","",InputFileName),"_L",as.character(CutOffPerc),"_Genes_Samples_BinaryMatrix.csv",sep = ""))
    
    write.table(Genes.Samples.Binary.df,file = File.Name,row.names = F,col.names = T,sep = ",")
    
    rm(Genes.Samples.Binary.df)
    
    #Outlier overlaps matrix
    SampleOverlaps.Matrix <- matrix(0,nrow = length(Non.Zero.Genes),ncol = length(Non.Zero.Genes))
    SampleOverlaps.Matrix <- Binary.Matrix.For.Genes.Outliers %*% t(Binary.Matrix.For.Genes.Outliers)
    SampleOverlaps.Matrix[lower.tri(SampleOverlaps.Matrix,diag = T)] <- -1
    
    #Hypergeometric test for overlaps (with alternative hypothesis that overlap is greater)
    
    Temp.Overlaps.Vec <- seq(0,ceiling(CutOffPerc*length(Sample.IDs)))
    
    p.val.Overlaps <- vector(mode = "numeric",length = length(Temp.Overlaps.Vec))
    for (i in 1:length(Temp.Overlaps.Vec))
    {
      t <- Temp.Overlaps.Vec[i]
      n <- length(Sample.IDs)
      a <- ceiling(CutOffPerc*length(Sample.IDs)) 
      b <- ceiling(CutOffPerc*length(Sample.IDs)) 
      p.val.Overlaps[i] <- sum(dhyper(t:b,a,n-a,b))
    }
    
    #Find overlap enrichments for all pairs
    p.values.Overlaps.Matrix <- matrix(-1,nrow = nrow(SampleOverlaps.Matrix),ncol = ncol(SampleOverlaps.Matrix))
    for (i in 1:length(Temp.Overlaps.Vec))
    {
      call <- cbind(which(SampleOverlaps.Matrix == Temp.Overlaps.Vec[i],arr.ind = T)[,1],which(SampleOverlaps.Matrix == Temp.Overlaps.Vec[i],arr.ind = T)[,2])
      p.values.Overlaps.Matrix[call] <- p.val.Overlaps[i]
    }
    
    #p-vals for special cases
    if (length(Genes.With.More.Zero.Samples) != 0) {
      Temp.Overlaps.Vec <- seq(0,ceiling(CutOffPerc*length(Sample.IDs)))
      
      p.values.List.More.Zeros <- vector(mode = "list",length = length(Genes.With.More.Zero.Samples))
      for (i in 1:length(p.values.List.More.Zeros))
      {
        p.val.Overlaps.Temp <- rep(1,length = length(Temp.Overlaps.Vec))
        TempI <- Genes.With.More.Zero.Samples[i]
        for (j in 1:length(Temp.Overlaps.Vec))
        {
          t <- Temp.Overlaps.Vec[j]
          n <- length(Sample.IDs)
          a <- Lengths.Zero.Samples[TempI]
          b <- ceiling(CutOffPerc*length(Sample.IDs))
          
          p.val.Overlaps.Temp[j] <- sum(dhyper(t:b,a,n-a,b))
          
        }
        p.values.List.More.Zeros[[i]] <- p.val.Overlaps.Temp
      }
      
      for (i in 1:length(Genes.With.More.Zero.Samples))
      {
        TempI <- Genes.With.More.Zero.Samples[i]
        p.val.Overlaps.Row.Temp <- p.values.Overlaps.Matrix[TempI,]
        p.val.Overlaps.Column.Temp <- p.values.Overlaps.Matrix[,TempI]
        for (j in 1:length(Temp.Overlaps.Vec))
        {
          if (length(which(SampleOverlaps.Matrix[TempI,] == Temp.Overlaps.Vec[j])) !=0) {
            p.val.Overlaps.Row.Temp[which(SampleOverlaps.Matrix[TempI,] == Temp.Overlaps.Vec[j])] <- p.values.List.More.Zeros[[i]][j]
          }
          if (length(which(SampleOverlaps.Matrix[,TempI] == Temp.Overlaps.Vec[j])) !=0) {
            p.val.Overlaps.Column.Temp[which(SampleOverlaps.Matrix[,TempI] == Temp.Overlaps.Vec[j])] <- p.values.List.More.Zeros[[i]][j]
          }
        }
        p.values.Overlaps.Matrix[TempI,] <- p.val.Overlaps.Row.Temp
        p.values.Overlaps.Matrix[,TempI] <- p.val.Overlaps.Column.Temp
      }
      
      Combn.Genes <- combn(Genes.With.More.Zero.Samples,2)
      
      for (i in 1:ncol(Combn.Genes))
      {
        TempI <- Combn.Genes[1,i]
        TempJ <- Combn.Genes[2,i]
        
        t <- SampleOverlaps.Matrix[TempI,TempJ]
        
        n <- length(Sample.IDs)
        
        x1 <- length(List.OutlierSamples.SerNos[[TempI]]) 
        
        x2 <- length(List.OutlierSamples.SerNos[[TempJ]])
        
        if (x1 <= x2) {
          a <- x2
          b <- x1
        } else {
          a <- x1
          b <- x2
        }
        
        p.values.Overlaps.Matrix[TempI,TempJ] <- sum(dhyper(t:b,a,n-a,b))
        
      }
    }
    
    p.values.Overlaps.Matrix[lower.tri(p.values.Overlaps.Matrix,diag = T)] <- -1
    
    rm(SampleOverlaps.Matrix)
    
    Non.Zero.Genes.Ser.Nos <- seq(1,length(Non.Zero.Genes))
    
    Col1.List <- vector(mode = "list",length = length(Non.Zero.Genes.Ser.Nos))
    Col2.List <- vector(mode = "list",length = length(Non.Zero.Genes.Ser.Nos))
    for (i in 1:length(Non.Zero.Genes.Ser.Nos))
    {
      if ((i-1) != 0) {
        Col2.List[[i]] <- rep(i,(i-1))
        Col1.List[[i]] <- seq(1, (i-1))
      }
    }
    
    Col1.Vec <- unlist(Col1.List)
    Col2.Vec <- unlist(Col2.List)
    
    rm(Col1.List)
    
    rm(Col2.List)
    
    p.val.Overlaps.Vec <- rep(1,length(Col1.Vec))
    
    p.val.Overlaps.Vec <- p.adjust(p.values.Overlaps.Matrix[upper.tri(p.values.Overlaps.Matrix)],method = "BH")
    
    rm(p.values.Overlaps.Matrix)
    
    Significant.Gene.Pairs <- which(p.val.Overlaps.Vec < 0.05)
    
    p.val.df <- data.frame(Col1.Vec[Significant.Gene.Pairs],Col2.Vec[Significant.Gene.Pairs],p.val.Overlaps.Vec[Significant.Gene.Pairs])
    
    colnames(p.val.df) <- c("Gene.1","Gene.2","p.val")
    
    File.Name <- as.character(paste(gsub(".csv","",InputFileName),"_L",as.character(CutOffPerc),"_SignificantGenePairs.csv",sep = ""))
    
    write.table(p.val.df,file = File.Name, row.names = F,col.names = T,sep = ",")
    
    #Code to generate plots
    
    if (length(p.val.df$p.val) > 1000000) {
      
      No.of.Edges <- vector(mode = "numeric")
      
      No.of.Genes <- vector(mode = "numeric")
      
      No.of.Samples <- vector(mode = "numeric")
      
      Exp.Power <- vector(mode = "numeric")
      
      No.of.Edges[1] <- 1
      
      Exp.Power[1] <- (min(p.val.df$p.val))
      
      k <- 1
      
      l <- 1
      
      while (No.of.Edges[l] < 1000000)
      {
        Relevant.Pairs <- which(p.val.df$p.val <= Exp.Power[k])
        No.of.Edges[k] <- length(Relevant.Pairs)
        No.of.Genes[k] <- length(union(p.val.df$Gene.1[Relevant.Pairs],p.val.df$Gene.2[Relevant.Pairs]))
        Samples.List.Relevant.Pairs <- vector(mode = "list",length = length(Relevant.Pairs))
        for (i in 1:length(Relevant.Pairs))
        {
          Samples.List.Relevant.Pairs[[i]] <- intersect(List.OutlierSamples.SerNos[[p.val.df$Gene.1[Relevant.Pairs[i]]]],List.OutlierSamples.SerNos[[p.val.df$Gene.2[Relevant.Pairs[i]]]])
        }
        No.of.Samples[k] <- length(unique(unlist(Samples.List.Relevant.Pairs)))
        
        k <- k+1
        Exp.Power[k] <- Exp.Power[k-1]*1000
        l <- k-1
      }
      
      Exp.Power <- Exp.Power[1:(k-1)]
      
      Genes.Per.Edge <- diff(No.of.Genes)/diff(No.of.Edges)
      
      Samples.Per.Edge <- diff(No.of.Samples)/diff(No.of.Edges)
      
      Diff.Genes <- diff(No.of.Genes)
      
      Diff.Samples <- diff(No.of.Samples)
      
      File.Name1 <- paste(gsub(".csv","",InputFileName),"_L",as.character(CutOffPerc),"_NoOfEdges.pdf",sep = "")
      pdf(File.Name1)
      plot(-log10(Exp.Power),No.of.Edges,xlab = "Significance of Overlap (-log10(p))",ylab = "Number of Edges in Graph",type = "o",col = "red",bg = "red",pch = 16)
      dev.off()
      
      File.Name2 <- paste(gsub(".csv","",InputFileName),"_L",as.character(CutOffPerc),"_GenesPerEdge.pdf",sep = "")
      pdf(File.Name2)
      plot(-log10(Exp.Power[2:(k-1)]),Genes.Per.Edge,xlab = "Significance of Overlap (-log10(p))",ylab = "Number of Genes Added/Number of Edges Added",type = "o",pch = 16,col = "red",bg = "red")
      dev.off()
      
      File.Name3 <- paste(gsub(".csv","",InputFileName),"_L",as.character(CutOffPerc),"_NoOfSamples.pdf",sep = "")
      pdf(File.Name3)
      plot(-log10(Exp.Power),No.of.Samples,xlab = "Significance of Overlap (-log10(p))",ylab = "Number of Samples",type = "o",pch = 16,col = "red",bg = "red")
      dev.off()
      
      File.Name4 <- paste(gsub(".csv","",InputFileName),"_L",as.character(CutOffPerc),"_SamplesPerEdge.pdf",sep = "")
      pdf(File.Name4)
      plot(-log10(Exp.Power[2:(k-1)]),Samples.Per.Edge,xlab = "Significance of Overlap (-log10(p))",ylab = "Number of Samples Added/Number of Edges Added",type = "o",pch = 16,col = "red",bg = "red")
      dev.off()
      
      File.Name5 <- paste(gsub(".csv","",InputFileName),"_L",as.character(CutOffPerc),"_GenesAdded.pdf",sep = "")
      pdf(File.Name5)
      plot(-log10(Exp.Power[2:(k-1)]),Diff.Genes,xlab = "Significance of Overlap (-log10(p))",ylab = "Number of Genes Added",type = "o",pch = 16,col = "red",bg = "red")
      dev.off()
      
      File.Name6 <- paste(gsub(".csv","",InputFileName),"_L",as.character(CutOffPerc),"_SamplesAdded.pdf",sep = "")
      pdf(File.Name6)
      plot(-log10(Exp.Power[2:(k-1)]),Diff.Samples,xlab = "Significance of Overlap (-log10(p))",ylab = "Number of Samples Added",type = "o",pch = 16,col = "red",bg = "red")
      dev.off()
      
    }
    rm(list = ls())
  }
  
} 