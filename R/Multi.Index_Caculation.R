## Autor
# Leon-Alvarado, Omar Daniel.
# leon.alvarado12@gmail.com

## License
# The follow script was created under the GNU/GPLv2. license.
# http://www.gnu.org/licenses/old-licenses/gpl-2.0-standalone.html

## Title
# Multiple Phylogenetic Diversity Index Calculation

## Description
# This R scripts perfomance the calculation of Taxonomic Distincness (DT) (Vane-Wrigth et al. 1991), Phylogenetic Diversity (PD) (Faith 1992) and Average Taxonomic Distincness (AvTD) (Clarke & Warwick 1998) for multiple distribution matrix and phylogenies
# This script requires two list objects: 
# 1. A list object with distribution matrices.
# 2. A list object with phylogenies.
# Species' names must be the same in the distribution matrices and phylogenies.
# The distribution matrices format to use are very specific, the same implemented in the package Jrich (Dmirandae/Jrich), see packages examples
# To use this script must change the working directories
# Two outcomes will generate, first a table with general information about species. Second a 3 list objecc correspond to each phylogenetic diversity index

####################################################################################3
toNum <-function(x){
  out <- matrix(NA, nrow = length(rownames(x)), ncol = length(colnames(x)))
  for (i in 1:length(colnames(x))){
    out[,i] <- as.numeric(x[,i])
  }
  colnames(out) <- colnames(x)
  rownames(out) <- rownames(x)
  
  return(out)
}

####################################################################################
avtd.root <- function(Phylo, Dist){
  
  rootName <- find.root(Phylo)
  
  for(i in 1:length(Dist[,1])){
    
    l <- grep(1,Dist[i, ])
    
    if(length(l)==1){
      
      Dist[i,grep(rootName,colnames(Dist))] <- 1
      
    }
    
  }
  
  return(Dist)
}
######################################################################################

find.root <- function(Phylo){
  
  library(ape, verbose = F,quietly = T)
  library(phangorn,verbose = F, quietly = T)
  
  ##########################################
  # Filter
  if(class(Phylo)!="phylo"){
    stop("Your input must be a class phylo")
  }
  if(is.rooted(Phylo)==F){
    stop("Your phylogeny must be rooted")
  }
  ###########################################
  
  RootNode <- length(Phylo$tip.label)+1
  
  Option <- c(1,length(Phylo$tip.label))
  
  RootTip <- c()
  
  for(i in 1:2){
    
    tip <- Option[i]
    
    Anc <- Ancestors(Phylo,tip)
    
    if(length(Anc)==1){
      
      RootTip <- Phylo$tip.label[Option[i]]
    }
  }
  
  if(is.null(RootTip)){
    
    warning("Your root terminal are not a unique specie, thus, just one will choose")
    
    for(i in 1:2){
      
      tip <- Option[i]
      
      Anc <- Ancestors(Phylo,tip)
      
      if(length(Anc)==2){
        
        RootTip <- Phylo$tip.label[Option[i]]
      }
    }
  }
  return(RootTip)
}

#################################################################################################


## Load libraries.

library(rgeos)
library(maptools)
library(rgbif)
library(dismo)
library(shapefiles)
library(ape)
library(phangorn)
library(phytools)
library(picante)
library(jrich)
library(SDMTools)

## Load the phylogenies and distributions


# Set working directory.
setwd("~/Documentos/Omar/Tesis/Taxa/Trees/")

# Read the directory.
dir.tree <- dir()[grep("_tree",dir())]
#dir.tree <- dir.tree[-grep("~",dir.tree)]

# Creat a empty list where we will put the trees.
multi.phylo <- list()

for (i in 1:length(dir.tree)){
  tree <- read.tree(dir.tree[i]) # Read each tree and...
  #plot.phylo(tree)
  multi.phylo[[i]] <- tree # Put inside the list, at the enda we create a multiphylo object.
}

names(multi.phylo) <- dir.tree

# Create a multidata with the ocurrences files created before.

setwd("~/Documentos/Omar/Tesis/Taxa/Results/Final2/")
dir.data <-(dir()[grep(".matrix",dir())])
#dir.data <- dir.data[-grep(".matrix~",dir.data)]

multi.data <- list()

for(i in 1:length(dir.data)){
  multi.data[[i]] <- read.csv(dir.data[i]) 
}

# Set names for each data.
names(multi.data) <- dir.data
str(multi.data)

## Extract the tips from all phylogenies
## Those species will be our pool data species, for the permutation

## Vector where the species will put

dead.pool <- c()
bl <- c()
tree.ref <- c()

## Extract all species terminals

for (i in 1:length(multi.phylo)){
  
  tax <- multi.phylo[[i]]$tip.label
  dead.pool <- c(dead.pool,tax)
  eg <- which(multi.phylo[[i]]$edge[,2]%in%1:length(multi.phylo[[i]]$tip.label))
  aa <- multi.phylo[[i]]$edge.length[eg]
  
  bl <- c(bl,aa)
  
  tree.ref <- c(tree.ref,rep(names(multi.phylo)[i],length(multi.phylo[[i]]$tip.label)))
  
}


DT.area <- c()
DT.grid <- c()
PD.area <- c()
PD.grid <- c()
AVDT.area <- c()
AVDT.grid <- c()

# Find the phylogeny species that match with the distribution species
match.sp <- dead.pool[which(dead.pool%in%multi.data[[1]]$especie)]
match.sp

write.csv(match.sp,"Match.sp", quote = F, row.names = F)

########################################################################

## Vector where the species will put

## Create empty lists for the original data results
dt.origin <- list()
pd.origin <- list() 
avtd.origin <- list()


for (i in 1:length(multi.phylo)){
  
   print(paste(paste("Phylogeny", i, sep=" "), paste("from", length(multi.phylo), sep=" "), sep=" "))
  
  # And for each distribution data
  for(j in 1:length(multi.data)){
    # Both data have the same species ? Extrac from the data distribution only the species shared with the phylogeny
    dist<- multi.data[[j]][which((multi.data[[j]]$especie%in%multi.phylo[[i]]$tip.label)==T),]
    # Sometimes after the below process are more species in the phylogeny than the distribution data
    if(length(dist$especie)<length(multi.phylo[[i]]$tip.label)){
      # Extrac from the phylogeny the specie that miss in the data distribution
      miss.sp <- multi.phylo[[i]]$tip.label[which((multi.phylo[[i]]$tip.label%in%dist$especie)==F)]
      # Create a vector with distribution species and the miss specie, it will be necessary next.
      sp <- c(as.character(dist$especie),miss.sp)
      # Now attach the miss specie(s) to the distribution matrix.
      # Because this specie not present occurences in the area, the row will fill with 0
      for (x in 1:length(miss.sp)){
        dist.tmp <- rep(NA,length(colnames(dist)))
        dist <- rbind(dist,dist.tmp)
        dist[length(dist$especie),2:length(colnames(dist))] <- 0
      }
      # Now replace the species column with the sp vector created before
      dist$especie <- sp
    }
    
    # First, extract colnames and species in different vectors.
    sp.dist0 <- dist$especie
    areas0 <- colnames(dist)
    
    # Remove the species colum, and the transpose the matrix.
    # The transpose is necessary for PD function.
    dist2<- dist[,-1]
    dist2 <- t(dist2)
    
    
    if (is.numeric(dist2[1,1])==F){
      
      dist2 <- toNum(dist2)
      
    }
    
    
    # Put the species' names as column names
    colnames(dist2) <- sp 
    
    # DT Calculation
    Ind <- Calculate.Index(tree=multi.phylo[[i]],dist=dist,verbose = F)
    # Extract areas' name
    name.data <- Ind$area
    # If is the firs phylogeny, not sum
    if(i == 1){
      dt.origin[[j]] <- Ind
      # But, if is not the first phylogeny, sum
    }else{
      # Due to characters object can't be summed, fill its colum with NA
      dt.origin[[j]]$area <- NA
      Ind$area <- NA
      # Make the sum and the re-assign the areas' name
      dt.origin[[j]] <- dt.origin[[j]] + Ind
      dt.origin[[j]]$area<- name.data
    }
    
    #PD Calculation
    pd <- pd(samp = dist2, tree = multi.phylo[[i]] , include.root = T)
    # Because the areas' names are row.names, there is no problem during sum
    if (i == 1){ 
      pd.origin[[j]] <- pd
    }else{
      pd.origin[[j]] <- pd.origin[[j]] + pd}
    
    #AvDT calculation
    
    
    distRoot <- avtd.root(Phylo = multi.phylo[[i]],Dist = dist2)
    
    tree.dist <- cophenetic.phylo(multi.phylo[[i]])
    
    avdt <- taxondive(comm = distRoot, dis = tree.dist)
    # Because the avdt are taxodive clase, it need transform to a data.frame
    avdt2 <- data.frame(Species=avdt$Species,
                        D=avdt$D,
                        Dstar=avdt$Dstar,
                        Lambda=avdt$Lambda,
                        Dplus=avdt$Dplus,
                        sd.Dplus=avdt$sd.Dplus,
                        SDplus=avdt$SDplus,
                        ED=avdt$ED,
                        EDstar=avdt$EDstar,
                        EDplus=avdt$EDplus)
    
    if(i == 1){
      avtd.origin[[j]] <- avdt2
    }else{
      
      avdt2[is.na(avdt2)] <- 0
      avtd.origin[[j]][is.na(avtd.origin[[j]])] <- 0
      
      avtd.origin[[j]] <- avtd.origin[[j]] + avdt2}
    
    ## Add the phylogenetic value of each phylogeny to a specific vector
    # 1 is for areas of endemism 
    # 2 is for cells of grid
    if(j==1){
      DT.area <- c(DT.area,rep(sum(Ind$W),length(dist$especie)))
      PD.area <- c(PD.area,rep(sum(pd$PD),length(dist$especie)))
      AVDT.area <- c(AVDT.area,rep(sum(avdt2$Dplus),length(dist$especie)))
    }
    if(j==2){
      DT.grid <- c(DT.grid,rep(sum(Ind$W),length(dist$especie)))
      PD.grid <- c(PD.grid,rep(sum(pd$PD),length(dist$especie)))
      AVDT.grid <- c(AVDT.grid,rep(sum(avdt2$Dplus),length(dist$especie)))
    }
    
  }
}

end.sp <- c()

for (i in 1:length(multi.data[[1]]$especie)){
  
  if(length(which(multi.data[[1]][i,]==1))==1){
    print(paste(multi.data[[1]]$especie[i],"es endémica"))
    end.sp <- c(end.sp,as.character(multi.data[[1]]$especie[i]))
  }
  
}

end.sp

general.info <- data.frame(Sp=dead.pool,
                           BL=bl,
                           Tree.ref=tree.ref,
                           DT.area=DT.area,
                           DT.grid=DT.grid,
                           PD.area=PD.area,
                           PD.grid=PD.grid,
                           AvDT.area=AVDT.area,
                           AvDT.grid=AVDT.grid,
                           Ende.WD=rep(NA,length(dead.pool)))
head(general.info,7L)


general.info$Ende.WD[which(general.info$Sp%in%end.sp)] <- rep("End",length(which(general.info$Sp%in%end.sp)))
general.info$Ende.WD[-which(general.info$Sp%in%end.sp)] <- rep("WD",length(general.info$Ende.WD[-which(general.info$Sp%in%end.sp)]))

general.info <- general.info[which(general.info$Sp%in%match.sp),]

head(general.info,7L)


write.table(general.info,file = "General.info",sep = ",", quote = F, col.names = T, row.names = F)

dir.data

out.names <- c("Area","grid1","grid25","grid50","PNN")

all.ind <- list(dt.origin,pd.origin,avtd.origin)

att <- c("DT","PD","AvTD")

setwd("~/Documentos/Omar/Tesis/Taxa/Results/May18/Raw_IndexR/")

for (i in 1:length(all.ind)){
  for (j in 1:length(out.names)){
    
    nn <- paste(att[i],out.names[j],sep=".")
    
    if( i == 3){
      write.table(all.ind[[i]][[j]], file = nn,
                  row.names = T, col.names = T, quote = F, sep = ",")
    }else{
      write.table(all.ind[[i]][[j]], file = nn,
                  row.names = F, col.names = T, quote = F, sep = ",")
    }    
    
  }
}

#############################################################################################
##                                                                                         ##
##                            2nd Approach, Nodesi - RootNode                              ##
##                                                                                         ##
#############################################################################################


find.root <- function(Phylo){
  
  library(ape, verbose = F,quietly = T)
  library(phangorn,verbose = F, quietly = T)
  
  ##########################################
  # Filter
  if(class(Phylo)!="phylo"){
    stop("Your input must be a class phylo")
  }
  if(is.rooted(Phylo)==F){
    stop("Your phylogeny must be rooted")
  }
  ###########################################
  
  RootNode <- length(Phylo$tip.label)+1
  
  Option <- c(1,length(Phylo$tip.label))
  
  RootTip <- c()
  
  for(i in 1:2){
    
    tip <- Option[i]
    
    Anc <- Ancestors(Phylo,tip)
    
    if(length(Anc)==1){
      
      RootTip <- Phylo$tip.label[Option[i]]
    }
  }
  
  if(is.null(RootTip)){
    
    warning("Your root terminal are not a unique specie, thus, just one will choose")
    
    for(i in 1:2){
      
      tip <- Option[i]
      
      Anc <- Ancestors(Phylo,tip)
      
      if(length(Anc)==2){
        
        RootTip <- Phylo$tip.label[Option[i]]
      }
    }
  }
  return(RootTip)
}

DistNodes1 <- function(BasalN, NiNode, Nnodes){
  
  Dist <- (BasalN * NiNode)/Nnodes
  
  return(Dist)
  
}

DistNodes2 <- function(BasalN, NiNode, Nnodes){
  
  Dist <- (BasalN - NiNode)/Nnodes
  
  return(Dist)
  
}

setwd("~/Documentos/Omar/Tesis/Taxa/Trees/")

# Read the directory.
dir.tree <- dir()[grep("_tree",dir())]
#dir.tree <- dir.tree[-grep("~",dir.tree)]

# Creat a empty list where we will put the trees.
multi.phylo <- list()

for (i in 1:length(dir.tree)){
  tree <- read.tree(dir.tree[i]) # Read each tree and...
  #plot.phylo(tree)
  multi.phylo[[i]] <- tree # Put inside the list, at the enda we create a multiphylo object.
}

names(multi.phylo) <- dir.tree

#######################################################################
#######################################################################

out <- matrix(0, nrow = 1, ncol = 5) #Species, Proportion, Nnodes, Dist1, Dist2
head(out)

for(i in 1:length(multi.phylo)){
  
  count1 <- matrix(NA, nrow = length(multi.phylo[[i]]$tip.label), ncol = 5)
  
  count1[ , 1] <- multi.phylo[[i]]$tip.label
  
  for(j in 1:length(multi.phylo[[i]]$tip.label)){
    
    nNodes <- multi.phylo[[i]]$Nnode
    
    dNodes <- length(Ancestors(multi.phylo[[i]], j))
    
    RootSp <- find.root(multi.phylo[[i]])
    
    PosRoot <- grep(RootSp, multi.phylo[[i]]$tip.label)
    
    RootNodes <- length(Ancestors(multi.phylo[[i]], PosRoot))
    
    Dist1 <- DistNodes1(RootNodes,dNodes,nNodes)
    
    Dist2 <- DistNodes2(RootNodes,dNodes,nNodes)
    
    proportion <- dNodes-RootNodes
    
    #proportion <- proportion*nNodes
    
    count1[j,2] <- proportion
    
    count1[j,3] <- nNodes
    
    count1[j,4] <- Dist1
    
    count1[j,5] <- Dist2
    
  }
  
  out <- rbind(out, count1)
  
}

colnames(out) <- c("Species", "Proportion", "Nnodes", "Dist1", "Dist2")

out <- as.data.frame(out[-1,])

head(out)


###########################################################

setwd("~/Documentos/Omar/Tesis/Taxa/Results/Final2/")

Gen.Info <- read.csv("General.info")

head(Gen.Info)

out <- out[which(out$Species%in%Gen.Info$Sp),]

Gen.Info <- cbind(Gen.Info,out)

head(Gen.Info)

Gen.Info

write.csv(Gen.Info, "Gen.Info4.csv",quote = F, row.names = F, col.names = T)

##########################################################
##########################################################

GI <- read.csv("Gen.Info4.csv")

str(GI)

##########################################################
##########################################################


smmr <- summary(GI$Proportion)
smmr

ggplot()+
  geom_histogram(aes(GI$Proportion))+
  geom_vline(aes(xintercept=smmr[2]))+ #1stQu
  geom_vline(aes(xintercept=smmr[5]))+ #3rdQu
  geom_vline(aes(xintercept=smmr[3], colour="Median"))+ #Median
  geom_vline(aes(xintercept=smmr[4], colour="Mean")) #Mean

ggplot()+
  geom_point(aes(x=GI$Nnodes, y=GI$Proportion))+
  geom_hline(aes(yintercept=smmr[2]), linetype = "longdash")+ #1stQu
  geom_hline(aes(yintercept=smmr[5]), linetype = "longdash")+ #3rdQu
  geom_hline(aes(yintercept=smmr[3], colour="Median"))+ #Median
  geom_hline(aes(yintercept=smmr[4], colour="Mean")) #Mean

##################################################3

GI2 <- GI[grep("End", GI$Ende.WD),]

smmr <- summary(GI2$Proportion)
smmr

ggplot()+
  geom_density(aes(GI2$Proportion), fill="black", alpha=.5)+
  geom_vline(aes(xintercept=smmr[2]))+ #1stQu
  geom_vline(aes(xintercept=smmr[5]))+ #3rdQu
  geom_vline(aes(xintercept=smmr[3], colour="Median"))+ #Median
  geom_vline(aes(xintercept=smmr[4], colour="Mean")) #Mean

ggplot()+
  geom_point(aes(x=GI2$Nnodes, y=GI2$Proportion))+
  geom_hline(aes(yintercept=smmr[2]), linetype = "longdash")+ #1stQu
  geom_hline(aes(yintercept=smmr[5]), linetype = "longdash")+ #3rdQu
  geom_hline(aes(yintercept=smmr[3], colour="Median"))+ #Median
  geom_hline(aes(yintercept=smmr[4], colour="Mean")) #Mean


#############################################################

GI2 <- GI[grep("WD", GI$Ende.WD),]

smmr <- summary(GI2$Proportion)
smmr

ggplot()+
  geom_density(aes(GI2$Proportion), fill="black", alpha=.5)+
  geom_vline(aes(xintercept=smmr[2]))+ #1stQu
  geom_vline(aes(xintercept=smmr[5]))+ #3rdQu
  geom_vline(aes(xintercept=smmr[3], colour="Median"))+ #Median
  geom_vline(aes(xintercept=smmr[4], colour="Mean")) #Mean

ggplot()+
  geom_point(aes(x=GI2$Nnodes, y=GI2$Proportion))+
  geom_hline(aes(yintercept=smmr[2]), linetype = "longdash")+ #1stQu
  geom_hline(aes(yintercept=smmr[5]), linetype = "longdash")+ #3rdQu
  geom_hline(aes(yintercept=smmr[3], colour="Median"))+ #Median
  geom_hline(aes(yintercept=smmr[4], colour="Mean")) #Mean


##########################################################################
##########################################################################




