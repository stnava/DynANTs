##########################################################################
dim=3
dir=/Users/stnava/data/MurrayLong/May2014LongitudinalTest/

# define time points
i=${dir}115629/20090311/Anatomy/115629_20090311_mprage_t1.nii.gz
j=${dir}115629/20091104/Anatomy/115629_20091104_mprage_t1.nii.gz
imglist=" $i $j "

# 0. as preprocessing, run all data through ACT

if [[ ! -s SSTtemplate0.nii.gz ]] ; then 
# 1. build a template from your ACT'd data to create a single subject template (SST)
# n4 was already done so -n 0 , also use the first volume as a starting point 
antsMultivariateTemplateConstruction2.sh -d $dim -o TEST  -i 4 -g 0.25  -j 0  -c 0 -k 1 -w 1 -e 0 \
  -f 8x4x2x1 -s 3x2x1x0 -q 100x70x50x3 \
  -n 0 -r 0  -l 1 -m MI -t SyN \
  -z $i  $imglist
  N3BiasFieldCorrection 3 SSTtemplate0.nii.gz   SSTtemplate0N3.nii.gz 8
  N3BiasFieldCorrection 3 SSTtemplate0N3.nii.gz SSTtemplate0N3.nii.gz 4
fi
echo SST is built

# 2. run the SST through ACT to a group template
DATA_DIR=${PWD}
TEMPLATE_DIR=./ADNI_3T/Normal/
SST_DIR=./SST_ACT
mkdir -p ${SST_DIR}
DOTEST=1
SSTPRE=SSTtestMode_
if [[ ! -s ${SST_DIR}/${SSTPRE}CorticalThickness.nii.gz ]] ; then 
  antsCorticalThickness.sh -d $dim -z $DOTEST \
    -a SSTtemplate0.nii.gz \
    -e ${TEMPLATE_DIR}T_template0.nii.gz \
    -f ${TEMPLATE_DIR}T_template0_BrainCerebellumExractionMask.nii.gz \
    -m ${TEMPLATE_DIR}T_template0_BrainCerebellumProbabilityMask.nii.gz  \
    -p ${TEMPLATE_DIR}Priors/priors%d.nii.gz \
    -o ${SST_DIR}/SST
fi
echo SST ACT is done 

# 3. run the time point images through ACT with the SST as template
# maybe should smooth posteriors before using them as priors ...
ct=0
# below may not be necessary
cp ${SST_DIR}/${SSTPRE}BrainExtractionMask.nii.gz ${SST_DIR}/${SSTPRE}BrainExtractionMask2.nii.gz
for img in $imglist ; do 
  OUT_DIR=subject_${ct}_long
  mkdir -p $OUT_DIR
  SUBPRE=subject_${ct}_longtestMode_
  if [[ ! -s ${OUT_DIR}/${SUBPRE}CorticalThickness.nii.gz ]] ; then 
    antsCorticalThickness.sh -d $dim -z $DOTEST \
      -a $img \
      -e SSTtemplate0N3.nii.gz \
      -m ${SST_DIR}/${SSTPRE}BrainExtractionMask.nii.gz  \
      -f ${SST_DIR}/${SSTPRE}BrainExtractionMask2.nii.gz  \
      -p ${SST_DIR}/${SSTPRE}BrainSegmentationPosteriors%d.nii.gz \
      -o ${OUT_DIR}/subject_${ct}_long
  fi
  let ct=$ct+1
done 

exit
# 4. build composite transformations from timepoints to template
# for each timepoint - fwd and inverse 
ct=0
for img in $imglist ; do
  antsApplyTransforms  # fwd
  antsApplyTransforms  # inv
  let ct=$ct+1
done
##########################################################################
########################***********done***********########################
##########################################################################
