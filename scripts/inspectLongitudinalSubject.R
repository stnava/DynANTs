library(ANTsR)
library(ggplot2)
library(date)
library(lme4)
library(nlme)
library(lmerTest)
library(packHV)
library(lattice)
##############################
##############################
mydf<-data.frame()
csvs<-Sys.glob("LongitudinalPEDS007/*/*mpr*brainvols.csv")
print(csvs)
for ( mycsv in csvs ) {
  subjectName<-unlist(strsplit(as.character(mycsv),".csv"))
  subjectName<-unlist(strsplit(as.character(subjectName),"/"))
  subjectName<-subjectName[length(subjectName)]
  temp<-read.csv(mycsv)
  temp<-cbind(temp,subject=rep(subjectName,nrow(temp)))
  if ( max(dim(mydf)) == 0 ) mydf<-temp else mydf<-rbind(mydf,temp)
}

# now create dates + uniqids
mydates<-list()
mydates2<-c()
myids<-rep("",nrow(mydf))
for ( i in 1:nrow(mydf) ) {
    ss<-strsplit(as.character(mydf$subject[i]),"_")
    locyear<-substr(ss[[1]][2],1,4)
    locmon<-substr(ss[[1]][2],5,6)
    locday<-substr(ss[[1]][2],7,8)
   ddd<-paste(locmon,locday,locyear,sep='/')
    mydates[[i]]<-as.date(ddd)
    mydates2[i]<-as.date(ddd)
    myids[i]<-as.character(ss[[1]][1])
}

mydf<-data.frame(myids,mydates2 ,mydelt=rep(0,nrow(mydf)),mydf)
ct<-2
while ( ct <= nrow(mydf) )
  {
  if ( mydf$myids[ct] ==   mydf$myids[ct-1] ) {
    basect<-which( mydf$myids == mydf$myids[ct] )
    mydf$mydelt[ct]<-as.date(mydf$mydates[ct])-as.date(mydf$mydates[basect[1]])
  }
  ct<-ct+1
  }

if ( FALSE ) {
countnas<-rep(0,ncol(mydf))
for ( i in 1:ncol(mydf) ) countnas[i]<-sum( is.na( mydf[,i] ) )
whcols<-which( countnas <= 8 )
mydf<-mydf[,whcols]
filtdf<-data.frame(na.omit(mydf))
# p<-ggplot(data=mydf, aes( x = mydelt, y = PearsonCorrelation, group = myids )) +   geom_line()  + geom_point()
# plot(p)
####
}
# 
for ( locid in levels(mydf$myids) ) {
imagelist<-Sys.glob(paste("LongitudinalPEDS007/*",locid,"*Thick*ToTemplate.nii.gz",sep=''))
maskfn<-Sys.glob(paste("LongitudinalPEDS007/",locid,"/SingleSubjectTemplate/*BrainSegmentationPosteriors02.nii.gz",sep=''))
imagelistfn<-Sys.glob(paste("LongitudinalPEDS007/*/*",locid,"*ToTemplateLogJacobian.nii.gz",sep=''))
maskfn<-Sys.glob(paste("LongitudinalPEDS007/SingleSubjectTemplate/*BrainExtractionMask.nii.gz",sep=''))
temfn<-Sys.glob(paste("LongitudinalPEDS007/SingleSubjectTemplate/*BrainSegmentation0N4.nii.gz",sep=''))
brain<-antsImageRead( temfn, 3 )
imagelist<-imageFileNames2ImageList( imagelistfn, 3 )
for ( img in imagelist ) SmoothImage(img@dimension,img,2.0,img)
dtime<-mydf$mydelt[ mydf$myids==locid ]
print(dtime)
print(maskfn)
mask<-antsImageRead(maskfn,3)
mask<-getMask(mask,lowThresh=0.5)
antsImageWrite(mask,'temp.nii.gz')
mat<-imageListToMatrix( imagelist, mask )
mycorrs<-as.numeric( cor(dtime,mat) )
corrs<-antsImageClone(mask) 
corrs[mask==1]<-mycorrs
ncorrs<-antsImageClone(mask) 
ncorrs[mask==1]<-mycorrs*(-1)
for ( a in 0:3 ) {
ofn<-paste(locid,"_axis_",a,'_delta_time_corrs.jpg',sep='')
plotANTsImage( brain, functional=list(corrs,ncorrs), threshold="0.8x1",slices="40x190x5",color=c("red","blue") , outname=ofn, alpha=0.25,axis=a)
}
}
derkaderka
antsImageWrite(corrs,paste(locid,'_delta_time_corrs.nii.gz',sep=''))
mylm<-lm( mat ~ dtime )
mybiglm<-bigLMStats( mylm, 0.1  )
betas<-antsImageClone(mask) # ,out_pixeltype='double')
fixbetas<-as.numeric(mybiglm$beta.t[1,])
# fixbetas[is.na(fixbetas)]<-0 
# ww<-( abs(fixbetas) > 10 | fixbetas == 0  )
ww<-rep(FALSE,ncol(mat))
fixbetas[ ww ]<-0
betas[mask==1]<-fixbetas
antsImageWrite(betas,paste(locid,'_delta_time_betas.nii.gz',sep=''))
fixpvs<-as.numeric(mybiglm$pval.model)
fixpvs[ww]<-1
fixpvs[!ww]<-1.0-p.adjust( fixpvs[!ww] )
betas[mask==1]<-fixpvs
antsImageWrite(betas,paste(locid,'_delta_time_qvals.nii.gz',sep=''))

hist( fixpvs )
