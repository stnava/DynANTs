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
basedir<-"LongitudinalOct16/*/*/*/*/*/*/"
csvs<-Sys.glob(paste(basedir,"*/*/*MPR*brainvols.csv",sep=''))
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
if ( TRUE ) {
countnas<-rep(0,ncol(mydf))
for ( i in 1:ncol(mydf) ) countnas[i]<-sum( is.na( mydf[,i] ) )
whcols<-which( countnas <= 8 )
mydf<-mydf[,whcols]
filtdf<-data.frame(na.omit(mydf))
p<-ggplot(data=mydf, aes( x = mydelt, y = PearsonCorrelation, group = myids )) +   geom_line()  + geom_point()
plot(p)
####
for ( jj in 4:8 )
  {
  imging<-filtdf[,jj]
  myform<-as.formula( paste("imging~mydelt+(1|myids)" ) )
  mxf<-lmer(myform,data=filtdf)
  smxf<-summary(mxf)
  print(smxf)
  locallabel<-colnames(filtdf)[jj]
  print(paste(locallabel))
  p<-ggplot(data=mydf, aes( x = mydelt, y = imging, group = myids )) +   geom_line()  + geom_point() + ggtitle(locallabel)
  plot(p)
}

}

#
bigct<-10
for ( locid in levels(mydf$myids) )
  {
imagelistfn<-Sys.glob(paste(basedir,"*/*/*",locid,"*Thickness.nii.gz",sep=''))
imagelistfn<-Sys.glob(paste(basedir,"*/*/*",locid,"*Posteriors02.nii.gz",sep=''))
  maskfn<-Sys.glob(paste(basedir,locid,"/SingleSubjectTemplate/*BrainSegmentationPosteriors02.nii.gz",sep=''))
  # imagelistfn<-Sys.glob(paste(basedir,"*/*/*",locid,"*ToTemplateLogJacobian.nii.gz",sep=''))
  # maskfn<-Sys.glob(paste(basedir,locid,"/SingleSubjectTemplate/*BrainExtractionMask.nii.gz",sep=''))
  temfn<-Sys.glob(paste(basedir,locid,"/SingleSubjectTemplate/*BrainSegmentation0N4.nii.gz",sep=''))

warpfn<-Sys.glob(paste(basedir,"*/*/*",locid,"*SubjectToTemplate1Warp.nii.gz",sep=''))
afffn<-Sys.glob(paste(basedir,"*/*/*",locid,"*SubjectToTemplate0GenericAffine.mat",sep=''))
#
warpfn<-Sys.glob(paste(basedir,"*/*/*",locid,"*SubjectToGroupTemplateWarp.nii.gz",sep=''))
 temimg<-antsImageRead("./LongitudinalOct16/data/jet/jtduda/data/TBI-Long/subjects/p025/SingleSubjectTemplate/T_templateCorticalThicknessNormalizedToTemplate.nii.gz",3)
#  brain<-antsImageRead( temfn, 3 )
   brain<-antsImageRead("./LongitudinalOct16/data/jet/jtduda/data/TBI-Long/subjects/p025/SingleSubjectTemplate/T_templateBrainNormalizedToTemplate.nii.gz",3)
  # mywarpedimage<-antsApplyTransforms(fixed=fixed,moving=moving,transformlist=mytx$fwdtransforms)
  ct<-1
  imagelist<-list()
  for ( jfn in imagelistfn ) {
    txlist<-c( warpfn[ct] ) # , afffn[ct] )
    jimg<-antsImageRead( jfn, 3)
    wimg<-antsApplyTransforms( fixed=temimg, moving=jimg, transformlist=txlist)
    antsImageWrite( wimg , paste('warped',bigct,'.nii.gz',sep='' ) )
    bigct<-bigct+1
    imagelist[[ct]]<-wimg
    ct<-ct+1
  }
  simagelist<-list()
  ct<-1
  for ( img in imagelist ) {
    simg<-antsImageClone(img)
    SmoothImage(img@dimension,img,3.0,simg)
    simagelist[[ct]]<-simg
    ct<-ct+1
  }
  tmask<-antsImageRead('PTBP/Priors/priors02.nii.gz',3)
  tmask[ tmask < 0.5 ]<-0
  tmask[ tmask >= 0.5 ]<-1
  dtime<-mydf$mydelt[ mydf$myids==locid ]
  mat<-imageListToMatrix( simagelist, tmask )
  # this produces high correlations for thinning
  mycorrs<-as.numeric( cor(rev(dtime),mat) )
  corrs<-antsImageClone(tmask)
  corrs[tmask==1]<-mycorrs
  ncorrs<-antsImageClone(tmask)
  ncorrs[tmask==1]<-mycorrs*(-1)
ofn<-paste(locid,'_delta_time_corrs.nii.gz',sep='')
antsImageWrite(corrs,ofn)
#  ofn<-paste(locid,'_delta_time_corrs.jpg',sep='')
#  plotANTsImage( brain, functional=list(corrs,ncorrs), threshold="0.8x1",slices="40x190x5",color=c("red","blue") , outname=ofn, alpha=0.25)
}
corrmat<-imagesToMatrix( Sys.glob("p*corrs.nii.gz"), tmask )
ttg<-rep(0,ncol(corrmat))
for ( i in 1:ncol(corrmat)) {
  ttg[i]<-t.test(corrmat[,i],alternative = "greater")$p.value
}
timg<-antsImageClone(tmask)
timg[tmask==1]<-1.0 - p.adjust( ttg, method='BH' )
antsImageWrite(timg,'corrtstatG.nii.gz')
# timg<-antsImageClone(tmask)
# timg[tmask==1]<-1.0 - p.adjust( tt, method='BH' )
# antsImageWrite(timg,'corrtstatL.nii.gz')
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
