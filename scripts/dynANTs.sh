#!/bin/bash

VERSION="0.0"

if [[ ! -s ${ANTSPATH}/antsRegistration ]]; then
  echo we cant find the antsRegistration program -- does not seem to exist.  please \(re\)define \$ANTSPATH in your environment.
  exit
fi
if [[ ! -s ${ANTSPATH}/antsApplyTransforms ]]; then
  echo we cant find the antsApplyTransforms program -- does not seem to exist.  please \(re\)define \$ANTSPATH in your environment.
  exit
fi
if [[ ! -s ${ANTSPATH}/N4BiasFieldCorrection ]]; then
  echo we cant find the N4 program -- does not seem to exist.  please \(re\)define \$ANTSPATH in your environment.
  exit
fi
if [[ ! -s ${ANTSPATH}/Atropos ]]; then
  echo we cant find the Atropos program -- does not seem to exist.  please \(re\)define \$ANTSPATH in your environment.
  exit
fi
if [[ ! -s ${ANTSPATH}/KellyKapowski ]]; then
  echo we cant find the DiReCT \(aka KellyKapowski\) program -- does not seem to exist.  please \(re\)define \$ANTSPATH in your environment.
  exit
fi
if [[ ! -e ${ANTSPATH}/antsBrainExtraction.sh ]]; then
  echo we cant find the antsBrainExtraction script -- does not seem to exist.  please \(re\)define \$ANTSPATH in your environment.
  exit
fi
if [[ ! -e ${ANTSPATH}/antsAtroposN4.sh ]]; then
  echo we cant find the antsAtroposN4 script -- does not seem to exist.  please \(re\)define \$ANTSPATH in your environment.
  exit
fi

function Usage {
    cat <<USAGE

`basename $0` performs longitudinal anatomical brain processing where the following steps are currently applied:

  0. construct single subject template then for each time-point, do:
  1. Brain extraction
  2. Brain n-tissue segmentation
  3. Cortical thickness
  4. (Optional) registration to a template

Usage:

`basename $0` -d imageDimension
              -a anatomicalImageList--timepoints-here
              -e brainTemplate
              -f brainExtractionRegionMaskLargerThanBrainProbabilityMask
              -m brainProbabilityMask
              -p brainSegmentationPriors
              <OPTARGS>
              -o outputPrefixes

Example:

  bash $0 -d 3 -e brainWithSkullTemplate.nii.gz -m brainPrior.nii.gz -p segmentationPriors%d.nii.gz -o output   -a t1a.nii.gz   -a t1b.nii.gz 

Required arguments:

We use *intensity* to denote the original anatomical image of the brain.

We use *probability* to denote a probability image with values in range 0 to 1.

We use *label* to denote a label image with values in range 0 to N.

     -d:  Image dimension                       2 or 3 (for 2- or 3-dimensional image)
     -a:  Anatomical image                      Structural *intensity* image, typically T1.  If more than one
                                                anatomical image is specified, subsequently specified
                                                images are used during the segmentation process.  However,
                                                only the first image is used in the registration of priors.
                                                Our suggestion would be to specify the T1 as the first image.
     -e:  Brain template                        Anatomical *intensity* template (possibly created using a population
                                                data set with buildtemplateparallel.sh in ANTs).  This template is
                                                *not* skull-stripped.
     -m:  Brain extraction probability mask     Brain *probability* mask created using e.g. LPBA40 labels which
                                                have brain masks defined, and warped to anatomical template and
                                                averaged resulting in a probability image.
     -p:  Brain segmentation priors             Tissue *probability* priors corresponding to the image specified
                                                with the -e option.  Specified using c-style formatting, e.g.
                                                -p labelsPriors%02d.nii.gz.  We assume that the first four priors
                                                are ordered as follows
                                                  1:  csf
                                                  2:  cortical gm
                                                  3:  wm
                                                  4:  deep gm
     -o:  Output prefix                         Should be of the form  BaseName/Time0Name/Time1Name/etcetera
                                                OUTPUT_PREFIX_FOR_TIMEPOINT=BaseName_Time0Name
                                                The following images are created:
                                                  * ${OUTPUT_PREFIX}BrainExtractionMask.${OUTPUT_SUFFIX}
                                                  * ${OUTPUT_PREFIX}BrainSegmentation.${OUTPUT_SUFFIX}
                                                  * ${OUTPUT_PREFIX}BrainSegmentation*N4.${OUTPUT_SUFFIX} One for each anatomical input
                                                  * ${OUTPUT_PREFIX}BrainSegmentationPosteriors*1.${OUTPUT_SUFFIX}  CSF
                                                  * ${OUTPUT_PREFIX}BrainSegmentationPosteriors*2.${OUTPUT_SUFFIX}  GM
                                                  * ${OUTPUT_PREFIX}BrainSegmentationPosteriors*3.${OUTPUT_SUFFIX}  WM
                                                  * ${OUTPUT_PREFIX}BrainSegmentationPosteriors*4.${OUTPUT_SUFFIX}  DEEP GM
                                                  * ...
                                                  * ${OUTPUT_PREFIX}BrainSegmentationPosteriors*N.${OUTPUT_SUFFIX} where there are N priors
                                                  *                              Number formatting of posteriors matches that of the priors.
                                                  * ${OUTPUT_PREFIX}CorticalThickness.${OUTPUT_SUFFIX}

Optional arguments:

     -s:  image file suffix                     Any of the standard ITK IO formats e.g. nrrd, nii.gz (default), mhd
     -t:  template for t1 registration          Anatomical *intensity* template (assumed to be skull-stripped).  A common
                                                use case would be where this would be the same template as specified in the
                                                -e option which is not skull stripped.
                                                We perform the registration (fixed image = individual subject
                                                and moving image = template) to produce the files.
                                                The output from this step is
                                                  * ${OUTPUT_PREFIX}TemplateToSubject0GenericAffine.mat
                                                  * ${OUTPUT_PREFIX}TemplateToSubject1Warp.${OUTPUT_SUFFIX}
                                                  * ${OUTPUT_PREFIX}TemplateToSubject1InverseWarp.${OUTPUT_SUFFIX}
                                                  * ${OUTPUT_PREFIX}TemplateToSubjectLogJacobian.${OUTPUT_SUFFIX}
     -f:  extraction registration mask          Mask (defined in the template space) used during registration
                                                for brain extraction.
     -k:  keep temporary files                  Keep brain extraction/segmentation warps, etc (default = 0).
     -i:  max iterations for registration       ANTS registration max iterations (default = 100x100x70x20)
     -w:  Atropos prior segmentation weight     Atropos spatial prior *probability* weight for the segmentation (default = 0.25)
     -n:  number of segmentation iterations     N4 -> Atropos -> N4 iterations during segmentation (default = 3)
     -b:  posterior formulation                 Atropos posterior formulation and whether or not to use mixture model proportions.
                                                e.g 'Socrates[1]' (default) or 'Aristotle[1]'.  Choose the latter if you
                                                want use the distance priors (see also the -l option for label propagation
                                                control).
     -u:  use random seeding                    Use random number generated from system clock in Atropos (default = 1)
     -r:  cortical label image                  Cortical ROI labels to use as a prior for ATITH.
     -l:  label propagation                     Incorporate a distance prior one the posterior formulation.  Should be
                                                of the form 'label[lambda,boundaryProbability]' where label is a value
                                                of 1,2,3,... denoting label ID.  The label probability for anything
                                                outside the current label

                                                  = boundaryProbability * exp( -lambda * distanceFromBoundary )

                                                Intuitively, smaller lambda values will increase the spatial capture
                                                range of the distance prior.  To apply to all label values, simply omit
                                                specifying the label, i.e. -l [lambda,boundaryProbability].

    
     -z:  Test / debug mode                     If > 0, runs a faster version of the script. Only for testing. Implies -u 0.
                                                Requires single thread computation for complete reproducibility.
USAGE
    exit 1
}

# Check outputs exist, runs at the end of the script
# List of outputs is taken from the usage
function checkOutputExists() {

  singleOutputs=( ${OUTPUT_PREFIX}BrainExtractionMask.${OUTPUT_SUFFIX} ${OUTPUT_PREFIX}BrainSegmentation.${OUTPUT_SUFFIX} ${OUTPUT_PREFIX}CorticalThickness.${OUTPUT_SUFFIX} )

  if [[ -f ${REGISTRATION_TEMPLATE} ]];
    then
      singleOutputs=( ${singleOutputs[@]} ${REGISTRATION_TEMPLATE_OUTPUT_PREFIX}0GenericAffine.mat ${REGISTRATION_TEMPLATE_OUTPUT_PREFIX}1Warp.${OUTPUT_SUFFIX} ${REGISTRATION_TEMPLATE_OUTPUT_PREFIX}1InverseWarp.${OUTPUT_SUFFIX} ${REGISTRATION_TEMPLATE_OUTPUT_PREFIX}LogJacobian.${OUTPUT_SUFFIX} )
    fi

  missingOutput=0

  for img in $singleOutputs;
    do
      if [[ ! -f $img ]];
        then
          echo "Missing output image $img"
          missingOutput=1
        fi
    done

  # Now check numbered output, numbers based on images
  for (( i = 0; i < ${#ANATOMICAL_IMAGES[@]}; i++ ))
    do
      if [[ ! -f ${OUTPUT_PREFIX}BrainSegmentation${i}N4.${OUTPUT_SUFFIX} ]];
        then
          echo "Missing output image ${OUTPUT_PREFIX}BrainSegmentation${i}N4.${OUTPUT_SUFFIX}"
          missingOutput=1
        fi
    done

  # Segmentation output depends on the number of priors and the numbering format
  segNumWidth=${#GRAY_MATTER_LABEL_FORMAT}

  for (( j = 1; j <= ${NUMBER_OF_PRIOR_IMAGES}; j++ ));
    do
      num=$(printf "%0${segNumWidth}d" $j)

      if [[ ! -f ${OUTPUT_PREFIX}BrainSegmentationPosteriors${num}.${OUTPUT_SUFFIX} ]];
        then
          echo "Missing output image ${OUTPUT_PREFIX}BrainSegmentationPosteriors${num}.${OUTPUT_SUFFIX}"
          missingOutput=1
        fi
    done

  if [[ $missingOutput -gt 0 ]];
    then
      echo "Some of the output does not exist"
      return 1
    fi

  return 0
}

echoParameters() {
    cat <<PARAMETERS

    Using antsCorticalThickness with the following arguments:
      image dimension         = ${DIMENSION}
      anatomical image        = ${ANATOMICAL_IMAGES[@]}
      brain template          = ${BRAIN_TEMPLATE}
      extraction prior        = ${EXTRACTION_PRIOR}
      extraction reg. mask    = ${EXTRACTION_REGISTRATION_MASK}
      segmentation prior      = ${SEGMENTATION_PRIOR}
      output prefix           = ${OUTPUT_PREFIX}
      output image suffix     = ${OUTPUT_SUFFIX}
      registration template   = ${REGISTRATION_TEMPLATE}

    ANTs parameters:
      metric                  = ${ANTS_METRIC}[fixedImage,movingImage,${ANTS_METRIC_PARAMS}]
      regularization          = ${ANTS_REGULARIZATION}
      transformation          = ${ANTS_TRANSFORMATION}
      max iterations          = ${ANTS_MAX_ITERATIONS}

    DiReCT parameters:
      convergence             = ${DIRECT_CONVERGENCE}
      thickness prior         = ${DIRECT_THICKNESS_PRIOR}
      gradient step size      = ${DIRECT_GRAD_STEP_SIZE}
      smoothing sigma         = ${DIRECT_SMOOTHING_SIGMA}

PARAMETERS
}

# Echos a command to stdout, then runs it
# Will immediately exit on error unless you set debug flag here
DEBUG_MODE=0

function logCmd() {
  cmd="$*"
  echo "BEGIN >>>>>>>>>>>>>>>>>>>>"
  echo $cmd
  $cmd

  cmdExit=$?

  if [[ $cmdExit -gt 0 ]];
    then
      echo "ERROR: command exited with nonzero status $cmdExit"
      echo "Command: $cmd"
      echo
      if [[ ! $DEBUG_MODE -gt 0 ]];
        then
          exit 1
        fi
    fi

  echo "END   <<<<<<<<<<<<<<<<<<<<"
  echo
  echo

  return $cmdExit
}

################################################################################
#
# Main routine
#
################################################################################

HOSTNAME=`hostname`
DATE=`date`

CURRENT_DIR=`pwd`/
OUTPUT_DIR=${CURRENT_DIR}/tmp$RANDOM/
OUTPUT_PREFIX=${OUTPUT_DIR}/tmp
OUTPUT_SUFFIX="nii.gz"

KEEP_TMP_IMAGES=1

DIMENSION=3

ANATOMICAL_IMAGES=()
REGISTRATION_TEMPLATE=""

USE_RANDOM_SEEDING=1

BRAIN_TEMPLATE=""
EXTRACTION_PRIOR=""
EXTRACTION_REGISTRATION_MASK=""
SEGMENTATION_PRIOR=""
CORTICAL_LABEL_IMAGE=""

CSF_MATTER_LABEL=1
GRAY_MATTER_LABEL=2
WHITE_MATTER_LABEL=3
DEEP_GRAY_MATTER_LABEL=4

ATROPOS_SEGMENTATION_PRIOR_WEIGHT=0.25

################################################################################
#
# Programs and their parameters
#
################################################################################

ANTS=${ANTSPATH}antsRegistration
ANTS_MAX_ITERATIONS="100x100x70x20"
ANTS_TRANSFORMATION="SyN[0.1,3,0]"
ANTS_LINEAR_METRIC_PARAMS="1,32,Regular,0.25"
ANTS_LINEAR_CONVERGENCE="[1000x500x250x100,1e-8,10]"
ANTS_METRIC="CC"
ANTS_METRIC_PARAMS="1,4"

WARP=${ANTSPATH}antsApplyTransforms

N4=${ANTSPATH}N4BiasFieldCorrection
N4_CONVERGENCE_1="[50x50x50x50,0.0000001]"
N4_CONVERGENCE_2="[50x50x50x50,0.0000001]"
N4_SHRINK_FACTOR_1=4
N4_SHRINK_FACTOR_2=2
N4_BSPLINE_PARAMS="[200]"

ATROPOS=${ANTSPATH}Atropos

ATROPOS_SEGMENTATION_INITIALIZATION="PriorProbabilityImages"
ATROPOS_SEGMENTATION_LIKELIHOOD="Gaussian"
ATROPOS_SEGMENTATION_CONVERGENCE="[5,0.0]"
ATROPOS_SEGMENTATION_POSTERIOR_FORMULATION="Socrates[1]"
ATROPOS_SEGMENTATION_NUMBER_OF_ITERATIONS=3
ATROPOS_SEGMENTATION_LABEL_PROPAGATION=()

DIRECT=${ANTSPATH}KellyKapowski
DIRECT_CONVERGENCE="[45,0.0,10]"
DIRECT_THICKNESS_PRIOR="10"
DIRECT_GRAD_STEP_SIZE="0.025"
DIRECT_SMOOTHING_SIGMA="1.5"
DIRECT_NUMBER_OF_DIFF_COMPOSITIONS="10"

USE_FLOAT_PRECISION=0

if [[ $# -lt 3 ]] ; then
  Usage >&2
  exit 1
else
  while getopts "a:b:d:e:f:h:i:k:l:m:n:p:q:r:o:s:t:u:w:z:" OPT
    do
      case $OPT in
          a) #anatomical t1 image
       ANATOMICAL_IMAGES[${#ANATOMICAL_IMAGES[@]}]=$OPTARG
       ;;
          b) # posterior formulation
       ATROPOS_SEGMENTATION_POSTERIOR_FORMULATION=$OPTARG
       ;;
          d) #dimensions
       DIMENSION=$OPTARG
       if [[ ${DIMENSION} -gt 3 || ${DIMENSION} -lt 2 ]];
         then
           echo " Error:  ImageDimension must be 2 or 3 "
           exit 1
         fi
       ;;
          e) #brain extraction anatomical image
       BRAIN_TEMPLATE=$OPTARG
       ;;
          f) #brain extraction registration mask
       EXTRACTION_REGISTRATION_MASK=$OPTARG
       ;;
          h) #help
       Usage >&2
       exit 0
       ;;
          i) #max_iterations
       ANTS_MAX_ITERATIONS=$OPTARG
       ;;
          k) #keep tmp images
       KEEP_TMP_IMAGES=$OPTARG
       ;;
          l)
       ATROPOS_SEGMENTATION_LABEL_PROPAGATION[${#ATROPOS_SEGMENTATION_LABEL_PROPAGATION[@]}]=$OPTARG
       ;;
          m) #brain extraction prior probability mask
       EXTRACTION_PRIOR=$OPTARG
       ;;
          n) #atropos segmentation iterations
       ATROPOS_SEGMENTATION_NUMBER_OF_ITERATIONS=$OPTARG
       ;;
          o) #output prefix
       OUTPUT_PREFIX=$OPTARG
       ;;
          p) #brain segmentation label prior image
       SEGMENTATION_PRIOR=$OPTARG
       ;;
          q) #use floating point precision
       USE_FLOAT_PRECISION=$OPTARG
       ;;
          r) #cortical label image
       CORTICAL_LABEL_IMAGE=$OPTARG
       ;;
          s) #output suffix
       OUTPUT_SUFFIX=$OPTARG
       ;;
          t) #template registration image
       REGISTRATION_TEMPLATE=$OPTARG
       ;;
          u) #use random seeding
       USE_RANDOM_SEEDING=$OPTARG
       ;;
          w) #atropos prior weight
       ATROPOS_SEGMENTATION_PRIOR_WEIGHT=$OPTARG
       ;;
          z) #debug mode
       DEBUG_MODE=$OPTARG
       ;;
          *) # getopts issues an error message
       echo "ERROR:  unrecognized option -$OPT $OPTARG"
       exit 1
       ;;
      esac
  done
fi


if [[ $DEBUG_MODE -gt 0 ]];
  then

   echo "    WARNING - Running in test / debug mode. Results will be suboptimal "

   # Speed up by doing fewer its. Careful about changing this because
   # certain things are hard coded elsewhere, eg number of levels

   ANTS_MAX_ITERATIONS="40x40x20x0"
   ANTS_LINEAR_CONVERGENCE="[100x100x50x0,1e-8,10]"
   ANTS_METRIC_PARAMS="1,2"

   # I think this is the number of times we run the whole N4 / Atropos thing, at the cost of about 10 minutes a time
   ATROPOS_SEGMENTATION_NUMBER_OF_ITERATIONS=1

   DIRECT_CONVERGENCE="[5,0.0,10]"

   # Fix random seed to replicate exact results on each run
   USE_RANDOM_SEEDING=0

  fi

################################################################################
#
# Preliminaries:
#  0. Check that output prefix is correctly formed
#  1. Check existence of inputs
#  2. Figure out output directory and mkdir if necessary
#  3. See if $REGISTRATION_TEMPLATE is the same as $BRAIN_TEMPLATE
#
################################################################################

nimg=${#ANATOMICAL_IMAGES[@]}
let nimgp1=$nimg+2
OUTPUT_PREFIX_VEC=()
basedir=`echo $OUTPUT_PREFIX | cut -d "," -f 1 `
baseID=`echo $OUTPUT_PREFIX | cut -d "," -f 2 `
for (( i = 2; i < nimgp1; i++ )); do
  let j=$i+1
  newentry=`echo $OUTPUT_PREFIX | cut -d "," -f $j `
  echo make output directory ${basedir}/${baseID}/${newentry}/
  mkdir -p ${basedir}/${baseID}/${newentry}/
#  mkdir -p ${basedir}/${baseID}/${newentry}/
  OUTPUT_PREFIX_VEC=("${OUTPUT_PREFIX_VEC[@]}" ${basedir}/${baseID}/${newentry}/${baseID}_${newentry} )
done
echo OUTPUT_PREFIX_VEC is ${OUTPUT_PREFIX_VEC[@]} of length ${#OUTPUT_PREFIX_VEC[@]}
if [[ ${#OUTPUT_PREFIX_VEC[@]} != $nimg ]] ; then 
  echo output variable poorly formed $OUTPUT_PREFIX
  echo OUTPUT_PREFIX should be of form  RootDir,SubjectID,TimeValue1,TimeValue2,...,TimeValueN
  echo and the number of entries beyond SubjectID should match the number of images
  exit 1
fi
for (( i = 0; i < ${#ANATOMICAL_IMAGES[@]}; i++ ))
  do
  echo check image ${ANATOMICAL_IMAGES[$i]}
  if [[ ! -f ${ANATOMICAL_IMAGES[$i]} ]];
    then
      echo "The specified image \"${ANATOMICAL_IMAGES[$i]}\" does not exist."
      exit 1
    fi
  done

if [[ ! -f ${BRAIN_TEMPLATE} ]];
  then
    echo "The extraction template doesn't exist:"
    echo "   $BRAIN_TEMPLATE"
    exit 1
  fi
if [[ ! -f ${EXTRACTION_PRIOR} ]];
  then
    echo "The brain extraction prior doesn't exist:"
    echo "   $EXTRACTION_PRIOR"
    exit 1
  fi

##########################################################################
# 0. as preprocessing, run all data through ACT
OUTPUT_PREFIX=${basedir}/${baseID}/
if [[ ! -s $OUTPUT_PREFIX ]] ; then 
  echo creating output directory $OUTPUT_PREFIX
  mkdir -p $OUTPUT_PREFIX
fi
dim=$DIMENSION
SST=${basedir}/${baseID}/${baseID}_SST
if [[ ! -s ${SST}template0N3.nii.gz ]] ; then 
# 1. build a template from your ACT'd data to create a single subject template (SST)
# n4 was already done so -n 0 , also use the first volume as a starting point 
  antsMultivariateTemplateConstruction2.sh -d $dim -o ${SST}  -i 4 -g 0.25  -j 0  -c 0 -k 1 -w 1 -e 0 -b 0 -a 0 \
    -f 8x4x2x1 -s 3x2x1x0 -q 100x70x50x3 \
    -n 0 -r 0  -l 1 -m MI -t SyN \
    -z ${ANATOMICAL_IMAGES[0]}  ${ANATOMICAL_IMAGES[@]} 
  N3BiasFieldCorrection 3 ${SST}template0.nii.gz   ${SST}template0N3.nii.gz 8
  N3BiasFieldCorrection 3 ${SST}template0N3.nii.gz ${SST}template0N3.nii.gz 4
fi
if [[ ! -s ${SST}template0N3.nii.gz ]] ; then 
  echo ${SST}template0N3.nii.gz is not built - exiting!
  exit 1  
fi
echo ${SST} is built --- now prior-based act with  $SEGMENTATION_PRIOR
if [[ ! -s $REGISTRATION_TEMPLATE ]] || [[ ${#REGISTRATION_TEMPLATE} -lt 3  ]] ; then
  echo please define REGISTRATION_TEMPLATE $REGISTRATION_TEMPLATE via the -t option
  exit 1
fi
# need to modify params below
# 2. run the SST through ACT to a group template
SST_DIR=${basedir}/${baseID}/${baseID}_SST_ACT/
mkdir -p ${SST_DIR}
SSTACT=${SST_DIR}/${baseID}_SST_ACT
######################################################
usequick=1
if [[ ! -s ${SSTACT}CorticalThickness.nii.gz ]] ; then 
  antsCorticalThickness.sh -d $dim -z $DEBUG_MODE -k $KEEP_TMP_IMAGES  -q $usequick \
    -a ${SST}template0.nii.gz \
    -e $BRAIN_TEMPLATE \
    -t $REGISTRATION_TEMPLATE \
    -f $EXTRACTION_REGISTRATION_MASK \
    -m $EXTRACTION_PRIOR  \
    -p $SEGMENTATION_PRIOR \
    -o ${SSTACT}
fi
if [[ $DEBUG_MODE -eq 1 ]] ; then 
  SSTACT=${SSTACT}testMode_
fi
if [[ ! -s ${SSTACT}CorticalThickness.nii.gz ]] ; then 
  echo SST ACT failed to produce ${SSTACT}CorticalThickness.nii.gz 
  exit 1
else 
  echo Successfully produced  ${SSTACT}CorticalThickness.nii.gz 
fi
if [[ ! -s ${SSTACT}ExtractedBrain0N4.nii.gz ]] ; then 
  echo SST ACT failed to produce ${SSTACT}ExtractedBrain0N4.nii.gz 
  exit 1
else 
  echo Successfully produced  ${SSTACT}ExtractedBrain0N4.nii.gz 
fi
# 3. run the time point images through ACT with the SST as template
# 3b. rigidly pre-align to SST
rigidprealign=1
if [[ $rigidprealign -eq 1 ]] ; then
  ct=0
  for img in ${ANATOMICAL_IMAGES[@]} ; do 
    SUBPRE=${OUTPUT_PREFIX_VEC[${ct}]}
    rigimg=${SUBPRE}_rigidWarped.nii.gz
    if [[ ! -s $rigimg ]] ; then
      N3BiasFieldCorrection 3 $img    $rigimg 8
      N3BiasFieldCorrection 3 $rigimg $rigimg 4
      antsRegistrationSyN.sh -d 3 -f ${SST}template0N3.nii.gz -m $rigimg -o ${SUBPRE}_rigid  -t r
    fi
    let ct=$ct+1
  done
fi

# maybe should smooth posteriors before using them as priors ...
ct=0
# below may not be necessary
cp ${SSTACT}BrainExtractionMask.nii.gz ${SSTACT}BrainExtractionMask2.nii.gz
for img in ${ANATOMICAL_IMAGES[@]} ; do 
  SUBPRE=${OUTPUT_PREFIX_VEC[${ct}]}
  rigimg=${SUBPRE}_rigidWarped.nii.gz
  if [[ -s $rigimg ]] ; then 
    img=$rigimg
    echo using $img rigidly prealigned 
  fi
  antsCorticalThickness.sh -d $dim -z $DEBUG_MODE -k $KEEP_TMP_IMAGES  -q $usequick   \
      -r ${SSTACT}CorticalThickness.nii.gz \
      -a $img \
      -w $ATROPOS_SEGMENTATION_PRIOR_WEIGHT  \
      -e ${SST}template0N3.nii.gz \
      -t ${SSTACT}ExtractedBrain0N4.nii.gz \
      -m ${SSTACT}BrainExtractionMask.nii.gz  \
      -f ${SSTACT}BrainExtractionMask2.nii.gz  \
      -p ${SSTACT}BrainSegmentationPosteriors%02d.nii.gz \
      -n 1 \
      -o ${SUBPRE}
  if [[ $DEBUG_MODE -eq 1 ]] ; then 
    SUBPRE=${SUBPRE}testMode_
  fi
  if [[ ! -s ${SUBPRE}CorticalThickness.nii.gz ]] ; then 
    echo Failed to produce ${SUBPRE}CorticalThickness.nii.gz 
    exit 1
  else 
    echo Successful ${SUBPRE}CorticalThickness.nii.gz 
  fi
  if [[ ! -s ${SUBPRE}ExtractedBrain0N4.nii.gz ]] ; then 
    echo Failed to produce ${SUBPRE}ExtractedBrain0N4.nii.gz 
    exit 1
  else 
    echo Successful ${SUBPRE}ExtractedBrain0N4.nii.gz 
  fi
  let ct=$ct+1
done 

# 4. build composite transformations from timepoints to template
# for each timepoint - fwd and inverse 
if [[ $KEEP_TMP_IMAGES -eq 1 ]] ; then 
echo now compose maps ...
ct=0
for img in ${ANATOMICAL_IMAGES[@]} ; do
  SUBPRE=${OUTPUT_PREFIX_VEC[${ct}]}
  if [[ $DEBUG_MODE -eq 1 ]] ; then 
    SUBPRE=${SUBPRE}testMode_
  fi
  rigimg=${SUBPRE}_rigidWarped.nii.gz
  if [[ -s $rigimg ]] ; then 
    img=$rigimg
    echo using $img rigidly prealigned 
  fi
  txs=" ${SSTACT}TemplateToSubject1GenericAffine.mat  
        ${SSTACT}TemplateToSubject0Warp.nii.gz 
        ${SUBPRE}TemplateToSubject1GenericAffine.mat  
        ${SUBPRE}TemplateToSubject0Warp.nii.gz
        ${SSTACT}SubjectToTemplate0GenericAffine.mat  
        ${SSTACT}SubjectToTemplate1Warp.nii.gz 
        ${SUBPRE}SubjectToTemplate0GenericAffine.mat  
        ${SUBPRE}SubjectToTemplate1Warp.nii.gz"
  for tx in $txs  ; do 
    if [[ ! -s $tx ]] ; then 
      echo $tx does not exist - exiting 
      exit 1
    fi
  done
  totem=" -t  ${SSTACT}SubjectToTemplate1Warp.nii.gz  
          -t  ${SSTACT}SubjectToTemplate0GenericAffine.mat
          -t  ${SUBPRE}SubjectToTemplate1Warp.nii.gz 
          -t  ${SUBPRE}SubjectToTemplate0GenericAffine.mat  "
  toind=" -t  ${SUBPRE}TemplateToSubject1GenericAffine.mat
          -t  ${SUBPRE}TemplateToSubject0Warp.nii.gz
          -t  ${SSTACT}TemplateToSubject1GenericAffine.mat
          -t  ${SSTACT}TemplateToSubject0Warp.nii.gz "  
  if [[ ! -s ${SUBPRE}_to_templateWarp.nii.gz ]]  ; then
    antsApplyTransforms -d $dim -r $BRAIN_TEMPLATE $totem -o [${SUBPRE}_to_templateWarp.nii.gz, 1 ] # fwd
  fi
  if [[ ! -s ${SUBPRE}_to_subjectWarp.nii.gz  ]]  ; then
    antsApplyTransforms -d $dim -r $img            $toind -o [${SUBPRE}_to_subjectWarp.nii.gz , 1 ] # inv
  fi
  thk=${SUBPRE}CorticalThickness.nii.gz
  antsApplyTransforms -d $dim -i $thk -r $BRAIN_TEMPLATE $totem -o ${SUBPRE}ThicknessToGroupTemplate.nii.gz # fwd
  if [[ ${#CORTICAL_LABEL_IMAGE} -gt 4 ]] ; then
    antsApplyTransforms -d $dim -i $CORTICAL_LABEL_IMAGE -r $img            $toind -o ${SUBPRE}_Label.nii.gz -n MultiLabel
    ThresholdImage 3 ${SUBPRE}BrainSegmentation.nii.gz ${SUBPRE}_LabelCort.nii.gz 2 2 
    MultiplyImages 3 ${SUBPRE}_Label.nii.gz ${SUBPRE}_LabelCort.nii.gz ${SUBPRE}_LabelCort.nii.gz
    ImageMath 3 ${SUBPRE}_LabelThickness.csv LabelStats ${SUBPRE}_LabelCort.nii.gz $thk
  fi
  let ct=$ct+1
done
fi
echo "##########################################################################"
echo "########################***********done***********########################"
echo "##########################################################################"
