
segs=pennTemplate/labels/pennWMmask.nii
segs=pennTemplate/labels/antsMalfLabels_6class.nii.gz
blob=temp/FTD_Stats_jacobianqv.nii.gz
blob=FTD_ROI_Long/malf_viz_THbvFTDRate.nii.gz
blob=FTD_ROI_Long/malf_viz_THsvPPARate.nii.gz
cp $blob blob.nii.gz
ThresholdImage 3 $segs surf.nii.gz 2 2
SurfaceBasedSmoothing blob.nii.gz 1 surf.nii.gz blob.nii.gz 5
blob=blob.nii.gz
ImageMath 3 $blob Byte $blob
# ThresholdImage 3 $blob blob.nii.gz 0.95 Inf
ext=stl
for seg in $segs ; do
  onm=`echo $seg | cut -d '.' -f 1`
  ThresholdImage 3 $seg wm.nii.gz 3 4
  ImageMath 3 wm.nii.gz GetLargestComponent wm.nii.gz
  if [[ ! -s thal.nii.gz ]] ; then
    ThresholdImage 3 $seg thal.nii.gz 4 4
    ImageMath 3 thal.nii.gz GetLargestComponent thal.nii.gz
    ImageMath 3 thal.nii.gz MD thal.nii.gz 2
  fi
  ImageMath 3 wm.nii.gz addtozero wm.nii.gz thal.nii.gz
  ImageMath 3 wm.nii.gz FillHoles wm.nii.gz
  ImageMath 3 wm.nii.gz GetLargestComponent wm.nii.gz
  ImageMath 3 wm.nii.gz MD wm.nii.gz 0
  topoits=500
  for smoo in  0.5 ; do
    echo J-Smoov $smoo
    SmoothImage 3 wm.nii.gz $smoo wms.nii.gz
#    ImageMath 3 wm.nii.gz MD wm.nii.gz 2
#    ImageMath 3 wm.nii.gz ME wm.nii.gz 3
#    ImageMath 3 wm.nii.gz GetLargestComponent wm.nii.gz
    ImageMath 3 wmt.nii.gz PropagateLabelsThroughMask wms.nii.gz thal.nii.gz $topoits 0
    ThresholdImage 3 wmt_label.nii.gz wmt.nii.gz 1  1
    SmoothImage 3 $blob 1.5 overlay.nii.gz
  ConvertScalarImageToRGB 3 overlay.nii.gz overlay_rgb.nii.gz blob.nii.gz hot
#     -f, --functional-overlay [rgbImageFileName,maskImageFileName,<alpha=1>]
    antsSurf -s [ wmt.nii.gz,255x255x255]  -f [ overlay_rgb.nii.gz, blob.nii.gz, 0.5 ] -d antsSurfEx2.png[270x0x120,255x255x255]  -o ${onm}.${ext} -i 100
  done
done
