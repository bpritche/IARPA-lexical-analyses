#!/bin/bash

# run a batch analysis on one subject
#
# for info about installation, usage, and dependencies see doc/readme.txt
# or execute with no parameters for a usage message
#
# Oliver Hinds <ohinds@mit.edu>
# todd thompson <toddt@mit.edu>
# mjp rul3zzzzz
# 2008-01-25


#### globals ####

exec_dir=`echo $0 | sed "s|\(.*/\).*|\1|"`

# name of the config file to read params from
config_filename="UNSET"

# where all the analysis specific files are (build_model.m, etc)
analysis_dir="UNSET"

# the top level directory containing all the subject directories for this study
study_subjs_dir="UNSET"

# path to batch_analysis_analysis dir
batch_analysis_home=/software/batch_analysis

# analysis unspecific matlab files dir (spm jobman templates, etc.)
matlab_dir="$batch_analysis_home"/matlab
matlab_dir_override=0

# analysis unspecific shell scripts dir (extract_motion_parms.sh, etc.)
script_dir="$batch_analysis_home"/scripts
script_dir_override=0

# path to customized art
art_dir="$batch_analysis_home"/matlab/art
art_dir_override=0

# analysis package homes
spm_dir=/software/spm5_1782
fsl_dir=/etc/fsl/fsl.sh

# freesurfer path
freesurfer_home=$FREESURFER_HOME

# stages to start and stop analysis at if partial analysis desiredx
startstage="first"
stopstage="last"


# individual stages

# be careful, just because you set something to 1 doesnt mean that the
# result is passed to the next stage. for example, setting only
# do_reslice=1 doesnt set do_normalize=0, and by default normalized
# ("w" prefix) files are passed along to the next analysis stage

do_slice_timing=0
do_fieldmap_correct=0
do_motion_correct=1
do_normalize=1
do_surf_project=0
do_preoutlier_model=1
do_outliers=1
do_view_funcruns=1
do_prepare_analysis=1
do_run_firstlevel=1
do_run_contrasts=1
do_surf_paint=0

# fieldmap correct options
fieldmap_defaults_file=
fieldmap_vdm_file=
fieldmap_total_epi_readout_time=

# motion correction options
do_reslice=0
use_moco_for_motion_estimate=0
use_fsl_for_motion_estimate=0
use_first_image_as_target=0

# smoothing options
do_vol_smooth=1
do_surf_vol_smooth=0
do_surf_smooth=0

# outlier options
skip_art_if_outliers_file_exists=0 # if outliers exist dont overwrite
same_outliers_as_base_model=1 # whether the current model has same outliers as
                              # base (same_runs_as_base_model better be 1, too!)
art_use_diffs=0
art_use_norms=0

# estimation options
TR=2
UNITS="scans"
hpf=128
do_vol_estimate=1
do_surf_estimate=0
skip_spm_orth=0

design_reporting=1
delete_old_analysis_without_asking=0 # delete old analyses automatically

save_res_images=0

model_config_file=
use_old_build_model=1

same_runs_as_base_model=1 # whether the current model has same runnums as base
fir_model=0
do_bayes_estimation=0 # use the spm baysian estimation method
no_design_matrix_temporal_filter=0 # skip temporal filtering of design matrix
no_ar_1_correct=0 # skip temporal correlation correction
use_temporal_deriv=1   # set to 0 in set_parm if do_slice_timing is set to 1
fsl_estimate=0 # whether to use fsl estimation in place of spm estimation
est_model_dir=            # look in a different dir than default for betas
fir_model=
fir_length=20
fir_order=10

# surf estimate options
dont_overwrite_resliced_big_niftis=0 # if sliced niftis exist dont overwrite

# contrast options
contrasts_config_file=

# surf paint options
paint_beta=0
paint_con=1
paint_t=1

# dangerousness
prefix_override=

## dont set these
prefix= # accumulated depending on processing steps

#### functions ####

# let em know how it is!
# TODO: add full descriptions of options (complete descriptions of -c and -m)
usage() {
    echo "$0 [options] subj"
    echo " options:"
    echo "   -c <config_filename>"
    echo "      name/value pairs, one to a line. any variable can be read from a config"
    echo "      file. for supported variables, see doc/example.cfg"

    echo "   -d <analysis_dir> "
    echo "      path to directory containing analysis specific matlab scripts"
    echo "       (build_model.m, build_contrasts.m, etc)"

    echo "   -D <study_subjs_dir> "
    echo "      path to directory containing the individual subject directories"

    echo "   -I <dicom_dir> "
    echo "      path to directory containing the dicom files for this subject"
    echo "      if this does not exist the most recent directory starting "
    echo "      with 'TrioTim' in the subject directory will be assumed "

    echo "   -b <batch_analysis_home> "
    echo "      path to directory containing the batch analysis distribution"

    echo "   -s <stage>: start at stage <stage>"
    echo "    stage can be:   "
    echo "       extract_motion"
    echo "       extract_volumes"
    echo "       slice_timing"
    echo "       fieldmap_correct"
    echo "       motion_correct"
    echo "       normalize"
    echo "       surf_project"
    echo "       smooth"
    echo "       preoutlier_model"
    echo "       outliers"
    echo "       view_funcruns"
    echo "       prepare_analysis"
    echo "       run_firstlevel"
    echo "       run_contrasts"
    echo "       surf_paint"

    echo "   -S <stage>: stop after stage <stage> (same options as start stage)"
    echo "   -R run numbers are different for this model than base model"
    echo "   -m <model>: create model_<model> instead of model (see doc/readme.txt)"
    echo "   -e [<estimated_model>]: use model_<estimated_model> to compute contrasts"
    echo "   -h, -?: print usage"
}

if [ ! "$1" ]; then
    usage
    exit
fi


# sets a parameter to a specified value
#
# in: paramter name and value pair
set_parm() {
    name="$1"
    value="$2"

    echo setting $name=\"$value\"

    # make the parm available
    export $name="$value"

    # check for special handling
    if [ "$name" == "batch_analysis_home" ]; then
	set_batch_analysis_home "$2"
    fi
    if [ "$name" == "matlab_dir" ]; then
	echo setting matlab_dir_override=1
	matlab_dir_override=1
    fi
    if [ "$name" == "script_dir" ]; then
	echo setting script_dir_override=1
	script_dir_override=1
    fi
    if [ "$name" == "art_dir" ]; then
	echo setting art_dir_override=1
	art_dir_override=1
    fi
    if [ "$name" == "est_model_dir" ]; then
	echo setting est_model_dir_override=1
	est_model_dir_override=1
    fi
    if [ "$name" == "slice_timing" -a "$value" == "1" ]; then
	echo "Using Slice Timing Correction; disabling temporal derivatives"
	use_temporal_deriv=0
    fi
}

# set the batch_analysis home
# updates the matlab, scripts, and art dir if they are not overriden.
#
# in: path to the batch_analysis home directory
set_batch_analysis_home() {
    batch_analysis_home=$1

    if [ $matlab_dir_override == "0" ]; then
	matlab_dir="$batch_analysis_home"/matlab
    fi

    if [ $script_dir_override == "0" ]; then
	script_dir="$batch_analysis_home"/scripts
    fi

    if [ $art_dir_override == "0" ]; then
	art_dir="$batch_analysis_home"/matlab/art
    fi
}


# parse command line arguments
#
# in: $@
parse_args() {
   # get the options
    while getopts ":c:d:D:e:h:s:S:m:RI:h?" Option
    do
	case $Option in
	    c ) set_parm config_filename "$OPTARG"
		;;
	    d ) set_parm analysis_dir "$OPTARG"
		;;
	    D ) set_parm study_subjs_dir "$OPTARG"
		;;
	    I ) set_parm dicom_dir "$OPTARG"
		;;
	    b ) set_parm batch_analysis_home "$OPTARG"
		;;
	    s ) set_parm startstage "$OPTARG"
		;;
	    S ) set_parm stopstage "$OPTARG"
		;;
	    m ) set_parm model "$OPTARG"
		;;
	    e ) set_parm est_model_dir "$OPTARG"
		;;
	    R ) set_parm same_runs_as_base_model 0;;
	    * ) usage;
		exit;;
	esac
    done
    shift $(($OPTIND - 1))

    subj=$1
}

# read parameters from a config file
# TODO: handle comments better
#
# in: configuration filename
read_configfile() {
    filename=$1;

    set -- `cat $filename | sed "/#/d; /^\s*$/d;"`
    while [ "$1" ]; do
	varval=`env | grep "^$1="`

	if [ ! "$varval" ]; then
	    set_parm $1 $2
	else
	    echo warning: not overidding $varval
	fi
	shift 2
    done
}

# validate configuration, report errors
# checks that required directories have been set
# TODO: check that the required files are in the directories, too
validate_config() {
    # analysis directory
    if [ "$analysis_dir" == "UNSET" ]; then
	echo "ERROR! analysis directory has not been set"
	usage;
	exit 1;
    fi

    echo testing
    if [ ! -d $analysis_dir ]; then	
    echo failed
	echo "ERROR! invalid analysis directory: $analysis_dir"
	usage;
	exit 1;
    fi
    echo succeded

    # study subjects directory
    if [ "$study_subjs_dir" == "UNSET" ]; then
	echo "ERROR! study_subjs directory has not been set"
	usage;
	exit 1;
    fi

    if [ ! -d "$study_subjs_dir" ]; then
	echo "ERROR! invalid study_subjs directory: $study_subjs_dir"
	usage;
	exit 1;
    fi

    # subject name
    if [ "$subj" == "UNSET" ]; then
	echo "ERROR! subect name is unset"
	usage;
	exit 1;
    fi

    # check paths
    if [ ! `which fslmaths` ]; then
	source "$fsl_dir/fsl.sh"
    fi

    if [ ! `which mri_info` ]; then
	export SUBJECTS_DIR=$PWD/..
	source "$freesurfer_home/SetUpFreeSurfer.sh"
    fi

    if [ "$model_config_file" ]; then
	if [ `echo $model_config_file | sed "s|\(\S\).*|\1|"` != '/' ]; then
	    model_config_file=$study_subjs_dir/$subj/$model_config_file
	fi

	# check exists
	if [ ! -e "$model_config_file" ]; then
	    echo "ERROR! model_config_file $model_config_file doesnt exist"
	    usage;
	    exit 1;	    
	fi
    fi

    if [ "$contrasts_config_file" ]; then
	if [ `echo $contrasts_config_file | sed "s|\(\S\).*|\1|"` != '/' ]; then
	    contrasts_config_file=$study_subjs_dir/$subj/$contrasts_config_file
	fi

	# check exists
	if [ ! -e "$contrasts_config_file" ]; then
	    echo "ERROR! contrasts_config_file $contrasts_config_file doesnt exist"
	    usage;
	    exit 1;	    
	fi
    fi
}

# dump the configuration to stdout
# TODO: do this for only our parms
dump_config() {
    env
}

# determine if a path is absolute
path_is_absolute() {
    if [ `echo $1 | sed "s/^\(.\).*/\1/"` == "/" ]; then
	return 1
    else
	return 0
    fi
}

# get the stem of the nifti files
get_niistem() {
    export niistem=`ls nii/[0-9]*.nii  | tail -n 1 | sed "s/-.*.nii/-/" | sed "s|nii/||"`
}

# map stage names to numbers
#
# in: name of desired stage number
get_stage_number() {
    name=$1

    case $name in
	first                        ) stage_num=1 ;;
	extract_motion               ) stage_num=1 ;;
	extract_volumes              ) stage_num=2 ;;
	slice_timing                 ) stage_num=3 ;;
	fieldmap_correct             ) stage_num=4 ;;
	motion_correct               ) stage_num=5 ;;
	normalize                    ) stage_num=6 ;;
	surf_project                 ) stage_num=7 ;;
	smooth                       ) stage_num=8 ;;
	preoutlier_model             ) stage_num=9 ;;
	outliers                     ) stage_num=10;;
	view_funcruns                ) stage_num=11;;
	prepare_analysis             ) stage_num=12;;
	run_firstlevel               ) stage_num=13;;
	run_contrasts                ) stage_num=14;;
	surf_paint                   ) stage_num=15;;
	last                         ) stage_num=15;;
	*                            ) stage_num=0;;
    esac
}

# map stage names to volume prefix addition
#
# in: name of desired stage number
update_prefix() {
    if [ "$prefix_override" ]; then
	export prefix=$prefix_override
	return
    fi

    name=$1

    case $name in
	slice_timing     )
	    if [ "$do_slice_timing" == 1 ] ; then
		prefix=a$prefix
	    fi
	    ;;

	fieldmap_correct     )
	    if [ "$do_fieldmap_correct" == 1 ] ; then
		prefix=u$prefix
	    fi
	    ;;

	motion_correct   )
	    if [ "$do_reslice" == 1 -a "$do_normalize" == 0 ] ; then
		prefix=r$prefix
	    fi
	    ;;

	normalize        )
	    if [ "$do_normalize" == 1 ] ; then
		prefix=w$prefix
	    fi
	    ;;

	surf_project        )
	    if [ "$do_surf_project" == 1 ] ; then
		lhprefix=lh$prefix
		rhprefix=rh$prefix
	    fi
	    ;;

	smooth           )
	    if [ "$do_vol_smooth" == 1 ] ; then
		prefix=s$prefix
	    fi
	    if [ "$do_vol_surf_smooth" == 1 ] ; then
		prefix=S$prefix
	    fi
	    if [ "$do_surf_smooth" == 1 ] ; then
		lhprefix=S$lhprefix
		rhprefix=S$rhprefix
	    fi
	    ;;
	* ) ;;
    esac

    export prefix=$prefix
}

# get the motion from the dicom headers
#
# in:
#     subject directory name
#     dicom directory name
extract_motion() {
    subjdir="$1";
    dcmdir="$2";

    # estimate motion
    echo "extracting motion"
    mkdir -p "$subjdir"/motion
    cd "$dcmdir";
    "$script_dir"/extract_motion_parms.sh -S -t spm -d "$subjdir"/motion/
    cd "$subjdir"

}

# convert the dicom directory into nifti volumes
#
# in: dicom directory name
extract_volumes() {
    dcmdir="$1"

    # extract nii files
    echo "extracting nii files from $dcmdir"
    mkdir -p nii
    "$script_dir"/dicomdir2nii.sh "$dcmdir" nii

}

# print available volumes and how many frames they have
print_avail_vols() {
    echo nothing
}

# slice-timing correction, if requested. (default is no)
slice_timing() {
    runnums="$1"

	#create matlab script to do slice timing correction via spm
    slice_timing_script=scripts/slice_timing.m
    echo "% auto-generated by $0" > $slice_timing_script
    echo "load "$matlab_dir"/slice_timing_job.mat" >> $slice_timing_script
    echo "addpath('scripts');" >> $slice_timing_script

    # build file list
    get_niistem
    echo "jobs{1}.temporal{1}.st.scans = {" >> $slice_timing_script
    for i in $runnums; do
	echo "'$PWD/nii/$niistem$i.nii'," >> $slice_timing_script
    done
    echo "};" >> $slice_timing_script

    if [ "$slice_timing_ref_slice" ]; then
	echo "jobs{1}.temporal{1}.st.refslice = $slice_timing_ref_slice;" >> $slice_timing_script
    fi

    if [ "$slice_timing_slice_order" ]; then
	echo "jobs{1}.temporal{1}.st.so = [$slice_timing_slice_order];" >> $slice_timing_script
    fi

    echo "spm_jobman('run',jobs);" >> $slice_timing_script

    "$script_dir"/run_matlab_script.sh "$slice_timing_script"
}

# set some filenames for fieldmap correcting
set_fieldmap_params() {

    get_niistem

    # paths to the images (and echo times if necessary)
    if [ ! "$fieldmap_mag_img" -a ! "$fieldmap_phs_img" ]; then
	# lotsa assumptions here ...
	for img in `ls $dicom_dir/*-1.dcm`; do
	    isfieldmap=`dicom_hdr $img | grep "ACQ Protocol Name" | grep "field_mapping"`
	    if [ "$isfieldmap" ]; then
		# check for mag img set (assume its first)
		if [ ! "$fieldmap_mag_img" ]; then
		    echo "found magnitude image: $img"

		    num=`echo $img | sed "s/.*[0-9]\+-\([0-9]\+\)-1.dcm/\1/"`
		    export fieldmap_mag_img=$PWD/nii/$niistem$num.nii;
		elif [ ! "$fieldmap_phs_img" ]; then
		    echo "found phase image: $img"

		    num=`echo $img | sed "s/.*[0-9]\+-\([0-9]\+\)-1.dcm/\1/"`
		    export fieldmap_phs_img=$PWD/nii/$niistem$num.nii;

		else
		    echo "ignoring extra fieldmap $img"
		fi
	    fi
	done
    fi

    # set echo times
    if [ ! "$fieldmap_short_echo" ]; then
	num=`echo $fieldmap_mag_img | sed "s/.*[0-9]\+-\([0-9]\+\).nii/\1/"`
	export fieldmap_short_echo=`dicom_hdr $dicom_dir/*-$num-1.dcm | grep "Echo Time" | sed "s|.*Echo Time//||"`
	echo "automatically set fieldmap_short_echo to $fieldmap_short_echo"
    fi

    if [ ! "$fieldmap_long_echo" ]; then
	num=`echo $fieldmap_phs_img | sed "s/.*[0-9]\+-\([0-9]\+\).nii/\1/"`
	export fieldmap_long_echo=`dicom_hdr $dicom_dir/*-$num-1.dcm | grep "Echo Time" | sed "s|.*Echo Time//||"`
	echo "automatically set fieldmap_long_echo to $fieldmap_long_echo"
    fi

    # set vdm filename
    if [ ! "$fieldmap_vdm_filename" ]; then
	num=`echo $fieldmap_phs_img | sed "s/.*[0-9]\+-\([0-9]\+\).nii/\1/"`
	export fieldmap_vdm_filename=$PWD/nii/vdm5_sc$niistem$num.nii
	echo "automatically set fieldmap_vdm_filename to $fieldmap_vdm_filename"
    fi

}

# spm fieldmap correction
#
# in: first functional run number
fieldmap_correct() {
    runnum="$1";
    get_niistem

    set_fieldmap_params

    # target epi image
    if [ ! "$fieldmap_epi_img" ]; then
	fieldmap_epi_img=$PWD/nii/$niistem$runnum.nii
    fi


    # make paths absolute
    path_is_absolute $fieldmap_mag_img
    if [ "$?" -ne 1 ]; then
	fieldmap_mag_img=$PWD/nii/$fieldmap_mag_img
    fi

    path_is_absolute $fieldmap_phs_img
    if [ "$?" -ne 1 ]; then
	fieldmap_phs_img=$PWD/nii/$fieldmap_phs_img
    fi

    path_is_absolute $fieldmap_epi_img
    if [ "$?" -ne 1 ]; then
	fieldmap_epi_img=$PWD/nii/$fieldmap_epi_img
    fi

    # error check
    if [ ! -f "$fieldmap_mag_img" -o ! -f "$fieldmap_phs_img" ]; then
	echo "magnitude or phase images not found! can't fieldmap correct"
	echo "fieldmap_mag_img: $fieldmap_mag_img"
	echo "fieldmap_phs_img: $fieldmap_phs_img"
	exit 0
    fi

    # readout time

    ## eventually
    #bandwidth=`dicom_hdr $dicom_dir/*$runnum-1.dcm | sed "s|.*Bandwidth//||"`;
    if [ ! "$fieldmap_total_epi_readout_time" ]; then
	echo "readout time not specified! can't fieldmap correct"
	return
    fi

    # defaults file
    if [ ! "$fieldmap_defaults_file" ]; then
	fieldmap_defaults_file="$matlab_dir/fieldmap_defaults.m"

	if [ ! "$fieldmap_short_echo" -o ! "$fieldmap_long_echo" ]; then
	    echo "both short and long echo times must be set! can't fieldmap correct"
	    return
	fi
    fi

    echo "$script_dir"/fieldmap_correct.sh \
	-m "$fieldmap_mag_img" \
	-p "$fieldmap_phs_img" \
	-e "$fieldmap_epi_img" \
	-f "$fieldmap_defaults_file" \
	-s "$fieldmap_short_echo" \
	-l "$fieldmap_long_echo" \
	-t "$fieldmap_total_epi_readout_time" \
	-d "$study_subjs_dir" \
	-D "$matlab_dir" \
	$subj

    "$script_dir"/fieldmap_correct.sh \
	-m "$fieldmap_mag_img" \
	-p "$fieldmap_phs_img" \
	-e "$fieldmap_epi_img" \
	-f "$fieldmap_defaults_file" \
	-s "$fieldmap_short_echo" \
	-l "$fieldmap_long_echo" \
	-t "$fieldmap_total_epi_readout_time" \
	-d "$study_subjs_dir" \
	-D "$matlab_dir" \
	$subj

}


# spm realign the functional runs
#
# in: functional run numbers
motion_correct() {
    runnums="$1";

    # set flags and prefix
    if [ "$do_reslice" == 1 ]; then
	reslice_flag=-R
    fi

    if [ "$do_fieldmap_correct" == 1 ]; then
	set_fieldmap_params

	reslice_flag=-R
	unwarp_flag="-U -V $fieldmap_vdm_filename"
    fi

    if [ $use_first_image_as_target == "0" ]; then
	target_flag=-m
    else
	target_flag=-f
    fi


    echo "$script_dir"/motion_correct.sh \
	-p "$prefix" \
	-r "$runnums" \
	-d "$study_subjs_dir" \
	$target_flag \
	$reslice_flag \
	$unwarp_flag \
	-D "$matlab_dir" \
	$subj

    "$script_dir"/motion_correct.sh \
	-p "$prefix" \
	-r "$runnums" \
	-d "$study_subjs_dir" \
	$target_flag \
	$reslice_flag \
	$unwarp_flag \
	-D "$matlab_dir" \
	$subj
}

# spm sptatial normalization
#
# in: functional run numbers
normalize() {
    runnums="$1";

    echo "$script_dir"/normalize_group_of_subjects.sh \
	 -t "$spm_dir"/templates/EPI.nii \
	 -d "$study_subjs_dir" \
	 -D "$matlab_dir" \
	 -B -C \
	 -p "$prefix" \
	 -r \"$1\" \
	 $subj
     "$script_dir"/normalize_group_of_subjects.sh \
	 -t "$spm_dir"/templates/EPI.nii \
	 -d "$study_subjs_dir" \
	 -D "$matlab_dir" \
	 -B -C \
	 -p "$prefix" \
	 -r "$1" \
	 $subj
}


# spm spatial smoothing
#
# in: list of functional run numbers
vol_smooth() {
    runnums="$1";

    if [ "$vol_fwhm" ]; then
	fwhm_flag="-f $vol_fwhm"
    fi

    echo "$script_dir"/volume_smooth.sh \
	-r "$runnums" \
	-p "$prefix" \
	-d "$study_subjs_dir" \
	-D "$matlab_dir" \
	$fwhm_flag \
	$subj

    "$script_dir"/volume_smooth.sh \
	-r "$runnums" \
	-p "$prefix" \
	-d "$study_subjs_dir" \
	-D "$matlab_dir" \
	$fwhm_flag \
	$subj
}

# unzip a file if it exists
#
# in
#  base filename
gunzip_file() {
    if [ -e "$1.gz" ]; then
	echo gunzip -f "$1.gz"
	gunzip -f "$1.gz"
    fi
}

# make a mask of all ones same size as template volume
#
# in
#  $1 template volume
#  $2 filename
create_mask_of_ones() {
    echo fslmaths "$1" -Tmean -mul 0 -add 1 "$2";
    fslmaths "$1" -Tmean -mul 0 -add 1 "$2";
    gunzip_file "$2"
}

# register mean functional volume to surface anatomical
#
#
reg_subject() {

    if [ "$use_first_image_as_target" == "1" ]; then	
	if [ "$model" ]; then
	    regtarget=nii/first_$model.nii
	else
	    regtarget=nii/first.nii
	fi

	first_ts_file=`ls nii/[0-9]*-$1.nii`

	echo "making registration target $regtarget"
	echo fslroi "$first_ts_file" "$regtarget" 0 1
	fslroi "$first_ts_file" "$regtarget" 0 1
	gunzip_file "$regtarget"
    else
	regtarget=`ls nii/mean*.nii`
    fi

    regtarget=`echo $regtarget | sed "s|nii/||"`

    if [ ! "$regtarget" ]; then
	echo "error, could not find motion correction regtarget for surface registration"
	return 1
    fi

    targname=`echo $regtarget | sed "s|.*/||; s|.nii||"`
    regfile=mri/transforms/"$targname"_to_struc.xfm
    if [ ! -e "$regfile" ]; then
	echo "$script_dir"/register_func_surf.sh \
	    -s $subj \
	    -f $PWD/nii/$regtarget \
	    -d "$study_subjs_dir" \
	    -r "$regfile"

	"$script_dir"/register_func_surf.sh \
	    -s $subj \
	    -f $PWD/nii/$regtarget \
	    -d "$study_subjs_dir" \
	    -r "$regfile"
    fi

    export regfile=$regfile
    export regtarget=$regtarget
}

# spatial smoothing on the surface but keep in the volume
#
# in: list of functional run numbers
surf_vol_smooth() {
    runnums="$1";

    if [ ! "$regfile" ]; then
	first_run=`echo $runnums | sed "s/ .*//"`
	reg_subject $first_run
    fi

    if [ "$surf_vol_fwhm" ]; then
	fwhm_flag="-f $surf_xvol_fwhm"
    fi

    echo "$script_dir"/smooth_vol_on_surf.sh \
	-r "$runnums" \
	-R "$regfile" \
	-P "$prefix" \
	-d "$study_subjs_dir" \
	$fwhm_flag \
	$subj
    "$script_dir"/smooth_vol_on_surf.sh \
	-r "$runnums" \
	-R "$regfile" \
	-P "$prefix" \
	-d "$study_subjs_dir" \
	$fwhm_flag \
	$subj
}

# surface projection
#
# in: list of functional run numbers
surf_project() {
    runnums="$1"

    if [ ! "$regfile" ]; then
	first_run=`echo $runnums | sed "s/ .*//"`
	reg_subject $first_run
    fi

   echo "$script_dir"/project_to_surface.sh \
       -r "$runnums" \
       -d "$study_subjs_dir" \
       -p "$prefix" \
       -R "$regfile" \
       $subj

   "$script_dir"/project_to_surface.sh \
       -r "$runnums" \
       -d "$study_subjs_dir" \
       -p "$prefix" \
       -R "$regfile" \
       -v \
       $subj
}

# smooth data on the surface
#
# in: list of functional run numbers
surf_smooth() {
    runnums="$1"

    if [ "$surf_fwhm" ]; then
	fwhm_flag="-f $surf_fwhm"
    fi

    echo "$script_dir"/smooth_surf_on_surf.sh \
	-r "$runnums" \
       -d "$study_subjs_dir" \
       -L $lhprefix \
       -R $rhprefix \
	$fwhm_flag \
	$subj
    "$script_dir"/smooth_surf_on_surf.sh \
	-r "$runnums" \
       -d "$study_subjs_dir" \
       -L $lhprefix \
       -R $rhprefix \
	$fwhm_flag \
	$subj
}

# split big niftis into multiple slices
#
# in:
#  $1 list of files
slice_big_nifti() {
    files="$1"

    echo slicing big niftis: $files

    # create a matlab script to take care of the big nifti issue
    bignii_script=scripts/bignii.m

    echo "% auto-generated by $0" > $bignii_script
    echo "addpath $matlab_dir" >> $bignii_script

    for i in $files; do
	nii=`echo $i | sed "s/fs.nii$/nii/"`

	if [ -e "$nii" -a "$dont_overwrite_resliced_big_niftis" == 1 ]; then
	    echo "skipping $nii because im not overwritting resliced niftis"
	else
	    echo "reshape_big_nifti('$i','$nii');" >> $bignii_script
	fi
    done
    "$script_dir"/run_matlab_script.sh "$bignii_script"
}

# unsplit niftis that were previously split into multiple slices
#
# in:
#  $1 number of surface vertices
#  $2 list of files
unslice_big_nifti() {
    numverts="$1"
    files="$2"

    echo unslicing to big niftis: $files

    # create a matlab script to un-take-care of the big nifti issue
    bignii_script=scripts/unbignii.m

    echo "% auto-generated by $0" > $bignii_script
    echo "addpath $matlab_dir" >> $bignii_script

    for i in $files; do
	fsnii=`echo $i | sed "s/img$/fs.nii/"`
	echo "unreshape_big_nifti('$i',$numverts,'$fsnii');" >> $bignii_script
    done
    "$script_dir"/run_matlab_script.sh "$bignii_script"
}

# run art to determine outliers
#
# in: functional run numbers
art_batch() {
    runnums="$1";

    # get image names for each session

    # build file list
    get_niistem

    if [ "$use_moco_for_motion_estimate" == 1 ]; then
	motstem="spm_motion-"
    elif [ "$use_fsl_for_motion_estimate" == 1 ]; then
	motstem="$niistem-"
    else
	motstem="rp_$niistem"
    fi

    ind=0;
    sess_str=""
    for i in $runnums; do
	let ind="ind+1"

	if [ "$use_moco_for_motion_estimate" == 1 ]; then
	    let motind="i+1"
	    motfname="spm_motion-$motind.txt"
	elif [ "$use_fsl_for_motion_estimate" == 1 ]; then
	    motfname="r$niistem-$i.nii.par"
	else
	    motfname="rp_$niistem$i.txt"
	fi

	sess_str="$sess_str session $ind image $niistem$i.nii"
	mot_str="$mot_str session $ind motion $motfname"
    done

    # make the art session file
    art_sess_file=scripts/art_sess_file.asf
    echo "sessions: $ind" > $art_sess_file
    echo "global_mean: 1" >> $art_sess_file
    echo "drop_flag: 0" >> $art_sess_file

    if [ "$use_fsl_for_motion_estimate" == 1 ]; then
	echo "motion_file_type: 1" >> $art_sess_file
    else
	echo "motion_file_type: 0" >> $art_sess_file
    fi

    echo "image_dir: $PWD/nii" >> $art_sess_file

    if [ "$use_moco_for_motion_estimate" == 1 ]; then
	echo "motion_dir: $PWD/motion" >> $art_sess_file
    else
	echo "motion_dir: $PWD/nii" >> $art_sess_file
    fi

    echo "motion_fname_from_image_fname: 0" >> $art_sess_file

    if [ "$art_use_diffs" != "0" ]; then
	echo "use_diffs: 1" >> $art_sess_file
    else
	echo "use_diffs: 0" >> $art_sess_file
    fi

    if [ "$art_use_norms" != "0" ]; then
	echo "use_norms: 1" >> $art_sess_file
    else
	echo "use_norms: 0" >> $art_sess_file
    fi

    echo "end" >> $art_sess_file
    echo ""
    echo $sess_str >>  $art_sess_file
    echo $mot_str >>  $art_sess_file
    echo "end" >>  $art_sess_file

    art_script=scripts/art_batch.m

    echo "% auto-generated by $0" > $art_script
    echo "addpath " $art_dir >> $art_script
    echo "a=which('art');" >> $art_script
    echo "fprintf('art is at %s\n',a);" >> $art_script
    echo "art('sess_file','$art_sess_file');" >> $art_script
    echo "fprintf('make sure to save the outliers in the mat file:\n$PWD/nii/$outlierfile\npress enter to continue...'), pause;" >> $art_script
    "$script_dir"/run_matlab_script.sh -with-display "$art_script"
}

# view each functional run in fslview
#
# in: functional run numbers
view_funcruns() {
    runnums="$1"

    get_niistem
    for i in $runnums; do
	fslview $PWD/nii/$niistem$i.nii;
    done
}

# create spm model
#
# in:
#  $1 functional run numbers
#  $2 model name or "" for none
#  $3 modelspace vol or surf
#  $4 hemisphere (if modelspace is surf)
build_model() {
    runnums="$1";
    modelname="$2";
    if [ "$3" == "surf" -o "$3" == "surface" ]; then
	modelspace=surf
	hemi="$4"
    elif [ "$3" == "outlier" ]; then
	modelspace=outlier
    else
	modelspace=vol
    fi

    modeldir="model"

    if [ "$model_config_file" -o "$use_old_build_model" == "0" ]; then
	modelmfun="build_model2"
    else
	modelmfun="build_model"
    fi

    dir=$PWD/firstlevel;

    # create a matlab script
    model_script=scripts/model

    # look for a model type modifier
    if [ "$modelname" ]; then
	modeldir="$modeldir"_"$modelname"
	dir="$dir"_"$modelname"
	model_script="$model_script"_"$modelname"

	if [ ! "$model_config_file" ]; then
	    modelmfun="$modelmfun"_"$modelname"
	fi

	if [ "$same_outliers_as_base_model" -eq 1 ]; then
	    outlierfile=outliers.mat
	else
	    outlierfile=outliers_"$modelname".mat
	fi
    else
	outlierfile=outliers.mat
    fi

    # check if this is a surface analysis
    if [ "$modelspace" == "surf" ]; then
	dir="$dir"/$hemi
	model_script="$model_script"_$hemi
    elif [ "$modelspace" == "outlier" ]; then
	dir="$dir"/outlier
	model_script="$model_script"_outlier
    fi

    model_script="$model_script".m

    mkdir -p "$modeldir"

    echo "addpath('"$analysis_dir"/');" > $model_script
    echo "dbstop if error;" >> $model_script

    # write nii file list based on model space
    echo "runs = {" >> $model_script
    niinum=`ls nii/[0-9]*.nii  | tail -n 1 | sed "s/-.*.nii/-/;s/nii.//"`
    if [ "$modelspace" == "surf" ]; then
	if [ "$hemi" == "lh" ]; then
	    hemiprefix=$lhprefix
	else
	    hemiprefix=$rhprefix
	fi

	niistem=`ls nii/$hemiprefix[0-9]*.nii  | tail -n 1 | sed "s/-.*.nii/-/"`

	explicit_mask=
	for f in $runnums; do
	    echo "'$PWD/$niistem$f.nii'," >> $model_script

	    # determine if there are big niftis that need slicing
	    bn=`ls $PWD/nii/$hemiprefix*-$f.fs.nii`;
	    if [ "$bn"  ]; then
		slice_big_nifti "$bn"
	    fi

	    # build a mask of all ones same size as surface volume SPM SUX!
	    if [ ! "$explicit_mask" ]; then
		explicit_mask=$PWD/nii/ones_mask_$hemi.nii
		create_mask_of_ones "$PWD/$niistem$f.nii" "$explicit_mask"
	    fi

	done

    else # find volumes
	get_niistem
	niinum=`ls nii/[0-9]*.nii  | tail -n 1 | sed "s/-.*.nii/-/;s/nii.//"`
	for i in $runnums; do
	    echo "'$PWD/nii/$prefix$niistem$i.nii'," >> $model_script
	done
    fi

    echo "};" >> $model_script

    # build motionfile list
    echo "motfiles = {" >> $model_script
    for i in $runnums; do
	if [ "$use_moco_for_motion_estimate" == 1 ]; then
	    motfname="motion/spm_motion-$j.txt"
	elif [ "$use_fsl_for_motion_estimate" == 1 ]; then
	    motfname="nii/r$niinum$i.nii.par"
	else
	    motfname="nii/rp_$niinum$i.txt"
	fi

	echo "'$PWD/$motfname'," >> $model_script
    done
    echo "};" >> $model_script

    # load outliers
    echo "" >> $model_script
    echo "out_idx = [];" >> $model_script
    echo "if(exist('$PWD/nii/$outlierfile','file'))" >> $model_script
    echo "  load('$PWD/nii/$outlierfile');" >> $model_script
    echo "  if(iscell(out_idx))" >> $model_script
    echo "    out_idx = out_idx{1};" >> $model_script
    echo "  end" >> $model_script
    echo "end" >> $model_script

    # load model goby
#    if [ "$fir_model" ]; then
#	echo "load "$matlab_dir"/firstlevel_fir_job.mat" >> $model_script
#    else
	echo "load "$matlab_dir"/firstlevel_job.mat" >> $model_script
#    fi

    # set tr
    echo "jobs{1}.stats{1}.fmri_spec.timing.RT = $TR;" >> $model_script
    echo "jobs{1}.stats{1}.fmri_spec(1).timing.units='$UNITS';" >> $model_script

    # delete previous analysis if there and required
    if [ -e "$dir/SPM.mat" -a "$delete_old_analysis_without_asking" == 1 ]; then
	echo "WARNING: removing existing analysis in $dir!!!!"
	rm "$dir/SPM.mat"
    fi

    mkdir -p "$dir"
    echo "jobs{1}.stats{1}.fmri_spec(1).dir = {'$dir'};" >> $model_script

    # temporal derivatives
    if [ "$fir_model" == 1 ]; then
	echo "jobs{1}.stats{1}.fmri_spec(1).bases = struct();" >> $model_script
	echo "jobs{1}.stats{1}.fmri_spec(1).bases.fir.length = $fir_length;" >> $model_script
	echo "jobs{1}.stats{1}.fmri_spec(1).bases.fir.order = $fir_order;" >> $model_script
    elif [ "$use_temporal_deriv" == 1 ]; then
	echo "jobs{1}.stats{1}.fmri_spec(1).bases.hrf.derivs = [1 0];" >> $model_script
    else
	echo "jobs{1}.stats{1}.fmri_spec(1).bases.hrf.derivs = [0 0];" >> $model_script
    fi

    # build model
    if [ "$model_config_file" -o "$use_old_build_model" == "0" ]; then
	echo " addpath $batch_analysis_home/matlab" >> $model_script
	echo " jobs{1}.stats{1}.fmri_spec(1).sess = $modelmfun('$subj','$study_subjs_dir','$modelname',runs,'$model_config_file',motfiles,out_idx,$hpf);"  >> $model_script
    else
	echo " jobs{1}.stats{1}.fmri_spec(1).sess = $modelmfun('$subj',runs,motfiles,out_idx);"  >> $model_script
    fi

    # run
    echo "dbstop if error"  >> $model_script
    echo "spm_jobman('run',jobs);" >> $model_script
    if [ "$design_reporting" -eq "1" ]; then
	echo "pause;" >> $model_script
    fi

    # set mask (SPM sucks!!)
    if [ "$explicit_mask" ]; then
	echo "load $dir/SPM;" >> $model_script
	#echo "SPM.xM = [];" >> $model_script
	echo "SPM.xM.VM = spm_vol('$explicit_mask');" >> $model_script
	echo "SPM.xM.I = 0;" >> $model_script
	echo "SPM.xM.T = [];" >> $model_script
	echo "SPM.xM.TH = ones(size(SPM.xM.TH))*(-Inf);" >> $model_script
	echo "SPM.xM.xs = struct('Masking', 'explicit masking only');" >> $model_script
	echo "save $dir/SPM SPM;" >> $model_script
    fi

    # set default non-sphericity for surfaces to be diagonal (dirty)
    if [ "$no_ar_1_correct" -eq "1" ]; then
	echo "WARNING!!! not using spm built-in AR(1) correction!!!"
	echo "load $dir/SPM;" >> $model_script
	echo "SPM.xVi.Vi = {speye(size(SPM.xX.X,1))};" >> $model_script
	echo "SPM.xVi.V  = speye(size(SPM.xX.X,1));" >> $model_script
	echo "save $dir/SPM SPM;" >> $model_script
    fi

    "$script_dir"/run_matlab_script.sh "$model_script"

    # turn off temporal filtering of the design matrix (SPM sux!!)
    if [ "$no_design_matrix_temporal_filter" -eq "1" ]; then
	echo "WARNING!!! not temporally filtering the design matrix!!!"
	echo "load $dir/SPM;" >> $model_script
	echo "SPM.xY.K = SPM.xX.K;" >> $model_script
	echo "SPM.xX.K = 1;" >> $model_script
	echo "save $dir/SPM SPM;" >> $model_script
    fi

    # warning, this probably does not work at all
    if [ "$save_res_images" -eq "1" ]; then
	echo "load $dir/SPM;" >> $model_script
	echo "SPM.xsDes.saveRes = true;" >> $model_script
	echo "save $dir/SPM SPM;" >> $model_script
    fi
}

# estimate firstlevel model, just choose between fsl and spm
#
# in:
#  $1 model name or "" for none
#  $2 modelspace vol or surf
#  $3 hemisphere (if modelspace is surf)
run_firstlevel() {
    if [ "$fsl_estimate" -eq "1" ]; then
	# run spm first to trick it into thinking that the model has
        # been estimated so that contrasts can be run
	echo "running dummy spm estimation......"
	run_firstlevel_spm "$1" "$2" "$3"

	echo "running reallife fsl estimation......"
	run_firstlevel_fsl "$1" "$2" "$3"
    else
	run_firstlevel_spm "$1" "$2" "$3"
    fi
}

# estimate firstlevel model using spm estimation
#
# in:
#  $1 model name or "" for none
#  $2 modelspace vol or surf
#  $3 hemisphere (if modelspace is surf)
run_firstlevel_spm() {
    modelname="$1";
    if [ "$2" == "surf" -o "$2" == "surface" ]; then
	modelspace=surf
	hemi="$3"
    else
	modelspace=vol
    fi

    firstleveldir=firstlevel

    # create a matlab script to do model estimation
    firstlevel_script=scripts/firstlevel

    # look for a model type modifier
    if [ "$modelname" ]; then
	firstleveldir="$firstleveldir"_"$modelname"
	firstlevel_script="$firstlevel_script"_"$modelname"
    fi

    # check if this is a surface analysis
    if [ "$modelspace" == "surf" ]; then
	firstleveldir="$firstleveldir"/$hemi
	firstlevel_script="$firstlevel_script"_$hemi
    fi

    firstlevel_script="$firstlevel_script".m


    echo "% auto-generated by $0" > $firstlevel_script

    if [ "$do_bayes_estimation" -eq "1" ]; then
	echo "load "$matlab_dir"/estimate_job_bayes.mat;" >> $firstlevel_script
    else
	echo "load "$matlab_dir"/estimate_job.mat;" >> $firstlevel_script
    fi
#    echo "addpath('scripts');" >> $firstlevel_script

    echo "spm_defaults;"  >> $firstlevel_script
    echo "jobs{1}.stats{1}.fmri_est(1).spmmat = {'$PWD/$firstleveldir/SPM.mat'};" >> $firstlevel_script

    if [ "$modelspace" == "surf" ]; then
	echo "load $PWD/$firstleveldir/SPM.mat" >> $firstlevel_script
	echo "SPM.xY.surf_estimation = true;"  >> $firstlevel_script
	echo "save $PWD/$firstleveldir/SPM.mat SPM" >> $firstlevel_script
    fi

    echo "dbstop if error"  >> $firstlevel_script
    echo "spm_jobman('run',jobs);" >> $firstlevel_script
#    echo "keyboard;" >> $firstlevel_script
    "$script_dir"/run_matlab_script.sh "$firstlevel_script"

}

# estimate firstlevel model using spm estimation
#
# in:
#  $1 model name or "" for none
#  $2 modelspace vol or surf
#  $3 hemisphere (if modelspace is surf)
run_firstlevel_fsl() {
    modelname="$1";
    if [ "$2" == "surf" -o "$2" == "surface" ]; then
	modelspace=surf
	hemi="$3"
    else
	modelspace=vol
    fi

    # check that there is only one run
    morethanonerun=`echo $runnums | grep -c "[[:space:]]"`;
    if [ "$morethanonerun" == "1" ]; then
	echo "error: fsl model fit on more than a sinlge run is not supported yet"
	echo "runnums were $runnums"
	exit
    fi

    firstleveldir=firstlevel

    # create a matlab script to convert the spm model
    firstlevel_script=scripts/modelconvert

    # look for a model type modifier
    if [ "$modelname" ]; then
	firstleveldir="$firstleveldir"_"$modelname"
	firstlevel_script="$firstlevel_script"_"$modelname"
    fi

    spmfirstleveldir="$firstleveldir"
    firstleveldir="$firstleveldir"_fsl

    # check if this is a surface analysis
    if [ "$modelspace" == "surf" ]; then
	firstleveldir="$firstleveldir"/$hemi
	firstlevel_script="$firstlevel_script"_$hemi
    fi

    firstlevel_script="$firstlevel_script".m


    # remove old analysis
    if [ -e "$firstleveldir" ]; then
	rm -rf $firstleveldir
    fi

    echo mkdir -p "$PWD/$firstleveldir"
    mkdir -p "$PWD/$firstleveldir"

    # convert the spm design
    fsldesign=$PWD/"$firstleveldir"/design

    echo "% auto-generated by $0" > $firstlevel_script
    echo "addpath('"$matlab_dir"/');" > $firstlevel_script

    echo "spm2fslDesign('$PWD/$spmfirstleveldir/SPM.mat','$fsldesign');" >> $firstlevel_script

    echo "dbstop if error"  >> $firstlevel_script
#    echo "keyboard;" >> $firstlevel_script
    "$script_dir"/run_matlab_script.sh "$firstlevel_script"

    # run the estimation
    run_file="$fsldesign"_datafiles.txt
    echo "film_gls -rn $firstleveldir -sa -ms 5 `cat $run_file` design.mat 100.0"
    film_gls -rn "$firstleveldir" -sa -ms 5 `cat $run_file` "$fsldesign".mat 100.0

    # copy all results from the plus directory (grrrrr)
    mv "$firstleveldir"+/* "$firstleveldir"
    rmdir "$firstleveldir"+

    # copy the pes to betas
    echo "copying pes to  betas...."
    for pe in `ls $firstleveldir/pe*`; do
	num=`echo $pe | sed "s/.*pe\([0-9].*\).nii/\1/"`
	betaname=`printf "%s/beta_%04d.img" "$spmfirstleveldir" $num`
	echo mri_convert $pe $betaname
	mri_convert $pe $betaname
    done
}

# run firstlevel contrasts
#
# in:
#  $1 model name or "" for none
#  $2 estimated model dir (for betas) if different from default model dir
#  $3 modelspace vol or surf
#  $4 hemisphere (if modelspace is surf)
run_contrasts() {
    if [ "$fsl_estimate" -eq "1" ]; then
	run_contrasts_fsl "$1" "$2" "$3" "$4"
    else
	run_contrasts_spm "$1" "$2" "$3" "$4"
    fi
}


# run firstlevel contrasts using model estimated using spm
#
# in:
#  $1 model name or "" for none
#  $2 estimated model dir (for betas) if different from default model dir
#  $3 modelspace vol or surf
#  $4 hemisphere (if modelspace is surf)
run_contrasts_spm() {
    modelname="$1";
    estimated_model_dir="$2"

    if [ "$3" == "surf" -o "$3" == "surface" ]; then
	modelspace=surf
	hemi="$4"
    else
	modelspace=vol
    fi

    firstleveldir=firstlevel
    contrastmfun="build_contrasts"

    # create a matlab script to do constrasts
    contrasts_script=scripts/contrasts

    # look for a model type modifier
    if [ "$modelname" ]; then
	firstleveldir="$firstleveldir"_"$modelname"
	contrasts_script="$contrasts_script"_"$modelname"

	if [ ! "$contrasts_config_file" ]; then
	    contrastmfun="$contrastmfun"_"$modelname"
	fi
    fi

    # look for a surface modelspace
    if [ "$modelspace" == "surf" ]; then
	firstleveldir="$firstleveldir"/$hemi
	contrastmfun="$contrastmfun"
	contrasts_script="$contrasts_script"_$hemi
    fi

    contrasts_script="$contrasts_script".m

    echo "% auto-generated by $0" > $contrasts_script
    echo "addpath('"$analysis_dir"/');" >> $contrasts_script

    echo "load $PWD/$firstleveldir/SPM;"  >> $contrasts_script
    echo "SPM.swd = '$PWD/$firstleveldir/';"  >> $contrasts_script
    echo "save $PWD/$firstleveldir/SPM.mat SPM;"  >> $contrasts_script

    echo "jobs{1}.stats{1}.con.spmmat = {'$PWD/$firstleveldir/SPM.mat'};"  >> $contrasts_script

    if [ ! "$contrasts_config_file" ]; then
	echo "jobs{1}.stats{1}.con.consess = $contrastmfun('$subj','$PWD/$firstleveldir/SPM.mat'$estimated_model_dir);"   >> $contrasts_script
    else
	echo "addpath $batch_analysis_home/matlab"  >> $contrasts_script
	echo "jobs{1}.stats{1}.con.consess = $contrastmfun('$subj','$PWD/$firstleveldir/SPM.mat'$estimated_model_dir,'$contrasts_config_file');"   >> $contrasts_script
    fi

    echo "dbstop if error"  >> $contrasts_script
#    echo "keyboard" >> $contrasts_script
    echo "spm_jobman('run',jobs);" >> $contrasts_script

    "$script_dir"/run_matlab_script.sh "$contrasts_script"
}

# run firstlevel fsl contrasts
#
# in:
#  $1 model name or "" for none
#  $2 estimated model dir (for betas) if different from default model dir
#  $3 modelspace vol or surf
#  $4 hemisphere (if modelspace is surf)
run_contrasts_fsl() {
    modelname="$1";
    estimated_model_dir="$2"

    if [ "$3" == "surf" -o "$3" == "surface" ]; then
	modelspace=surf
	hemi="$4"
    else
	modelspace=vol
    fi

    firstleveldir=firstlevel
    contrastmfun="build_contrasts"

    # create a matlab script to do constrasts
    contrasts_script=scripts/contrasts

    # look for a model type modifier
    if [ "$modelname" ]; then
	firstleveldir="$firstleveldir"_"$modelname"
	contrastmfun="$contrastmfun"_"$modelname"
	contrasts_script="$contrasts_script"_"$modelname"
    fi

    # look for a surface modelspace
    if [ "$modelspace" == "surf" ]; then
	firstleveldir="$firstleveldir"/$hemi
	contrastmfun="$contrastmfun"
	contrasts_script="$contrasts_script"_$hemi
    fi

    contrasts_script="$contrasts_script".m

    echo "% auto-generated by $0" > $contrasts_script
    echo "addpath('"$analysis_dir"/');" >> $contrasts_script

    echo "load $PWD/$firstleveldir/SPM;"  >> $contrasts_script
    echo "SPM.swd = '$PWD/$firstleveldir/';"  >> $contrasts_script
    echo "save $PWD/$firstleveldir/SPM.mat SPM;"  >> $contrasts_script

    echo "jobs{1}.stats{1}.con.spmmat = {'$PWD/$firstleveldir/SPM.mat'};"  >> $contrasts_script

    echo "jobs{1}.stats{1}.con.consess = $contrastmfun('$subj','$PWD/$firstleveldir/SPM.mat'$estimated_model_dir);"   >> $contrasts_script

    echo "dbstop if error"  >> $contrasts_script
#    echo "keyboard" >> $contrasts_script
    echo "spm_jobman('run',jobs);" >> $contrasts_script
    "$script_dir"/run_matlab_script.sh "$contrasts_script"
}

# convert contrasts for a model into paint files for surface visualization
#
# in:
#  $1 model name or "" for none
surf_paint() {
    modelname="$1";

    # look for a model type modifier
    firstleveldir=firstlevel
    if [ "$modelname" ]; then
	firstleveldir="$firstleveldir"_"$modelname"
    fi

    paint_script=scripts/paint.m

    # create surface viewable files of the contrasts
    echo "" > $paint_script
    echo "% create surface viewable files of the contrasts" >> $paint_script
    echo "addpath $matlab_dir" >> $paint_script

    for hemi in lh rh; do

	numverts=`mris_info surf/$hemi.white 2> /dev/null | sed -n "/num vertices/p" | sed "s/.* //"`

	# build a list of files to unslice
	slifiles=
	if [ "$paint_beta" == 1 ]; then # beta images
            # zero nans in the beta images
	    for file in `ls $PWD/$firstleveldir/$hemi/beta_*.img`; do
		zeroed=`echo $file | sed s/beta_/beta_zeronan_/ | sed s/.img/.nii/`
		echo fslmaths $file -nan $zeroed
		fslmaths $file -nan $zeroed
		gunzip_file $zeroed
	    done
	    slifiles="$slifiles `ls $PWD/$firstleveldir/$hemi/beta_zeronan_????.nii`"
	fi
	if [ "$paint_con" == 1 ]; then # con images
            # zero nans in the con images
	    for file in `ls $PWD/$firstleveldir/$hemi/con_*.img`; do
		zeroed=`echo $file | sed s/con_/con_zeronan_/ | sed s/.img/.nii/`
		echo fslmaths $file -nan $zeroed
		fslmaths $file -nan $zeroed
		gunzip_file $zeroed
	    done
	    slifiles="$slifiles `ls $PWD/$firstleveldir/$hemi/con_zeronan_????.nii`"
	fi
	if [ "$paint_t" == 1 ]; then # t maps
	    slifiles="$slifiles `ls $PWD/$firstleveldir/$hemi/spmT_????.img`"
	fi

	if [ ! "$slifiles" ]; then
	    echo "no files to reslice"
	    return
	fi

	if [ ! "$numverts" ]; then
	    echo cant determine number of surface vertices.
	    echo maybe your freesurfer environment is not setup?
	    return 1
	fi

	for file in $slifiles; do
	    fsnii=`echo $file | sed "s/nii$\|img$/fs.nii/"`
	    echo "unreshape_big_nifti('$file',$numverts,'$fsnii');" >> $paint_script

	    #paint=`echo $fsnii | sed "s/.fs.nii/.mgh/"`
	    #echo "v = nifti('$file');"  >> $paint_script
	    #echo "save_mgh(v.dat(1:$numverts),'$paint',eye(4));" >> $paint_script

	done
    done
    "$script_dir"/run_matlab_script.sh "$paint_script"
}


#
#

#### main body of the run_subject.sh script #####

# configuration and validation

parse_args $@;

if [ "$config_filename" != "UNSET" ]; then
    read_configfile "$config_filename"
fi

validate_config;

# set up the start and stop stages
get_stage_number $startstage
start_stage_num=$stage_num
echo running from $startstage to $stopstage

get_stage_number $stopstage
stop_stage_num=$stage_num

#validate start and stop names
if [ "$start_stage_num" == "0" ]; then
    echo "error: invalid start stage name $startstage"
    usage
    exit 0;
fi
if [ "$stop_stage_num" == "0" ]; then
    echo "error: invalid stop stage name $stopstage"
    usage
    exit 0;
fi

dir=$PWD

if [ ! "$subj" ]; then
    usage
    exit
fi

subjdir="$study_subjs_dir/$subj"

if [ ! -d "$subjdir" ]; then
    echo "invalid subjects directory: $subjdir"
    usage
    exit
fi

if [ ! "$dicom_dir" ]; then
    # only the most recent mri data directory
    dicom_dir=`ls -dtr $subjdir/TrioTim* 2> /dev/null | tail -n 1`
fi

get_stage_number "extract_motion"
if [ "$start_stage_num" -le "$stage_num" ]; then
    echo "found dicom directory $dicom_dir"
    extract_motion $subjdir $dicom_dir
fi
if [ "$stop_stage_num" -le "$stage_num" ]; then
    exit;
fi

get_stage_number "extract_volumes"
if [ "$start_stage_num" -le "$stage_num" ]; then
    echo "found dicom directory $dicom_dir"
    extract_volumes $dicom_dir
fi
if [ "$stop_stage_num" -le "$stage_num" ]; then
    exit;
fi

mkdir -p scripts

# find the functional runs
cd $subjdir
if [ ! -e  scripts/func_runs.txt ]; then
    summarize_dicomdir.sh "$dicom_dir"

    while [ 1 ] ; do
	echo "enter the run numbers of the functional runs (p to print again): "
	read runnums

	case runnums in
	    p ) ls nii;;
	    * ) echo "read $runnums"
		echo "enter 1 to accept, 0 to renter"
		read again
		if [ "$again" -eq 1 ]; then
		    break;
		fi
		;;
	esac
    done
    echo $runnums > scripts/func_runs.txt
else
    runnums=`cat scripts/func_runs.txt`
fi

get_stage_number "slice_timing"
if [ "$start_stage_num" -le "$stage_num" -a "$do_slice_timing" == 1 ]; then
    slice_timing "$runnums"
fi
if [ "$stop_stage_num" -le "$stage_num" ]; then
    exit;
fi
update_prefix "slice_timing"

get_stage_number "fieldmap_correct"
if [ "$start_stage_num" -le "$stage_num" -a "$do_fieldmap_correct" == 1 ]; then
    fieldmap_correct `echo $runnums s/ .*//`
fi
if [ "$stop_stage_num" -le "$stage_num" ]; then
    exit;
fi

get_stage_number "motion_correct"
if [ "$start_stage_num" -le "$stage_num" -a "$do_motion_correct" == 1 ]; then
    motion_correct "$runnums"
fi
if [ "$stop_stage_num" -le "$stage_num" ]; then
    exit;
fi
update_prefix "fieldmap_correct" # update the prefix here for fieldmap too coz
                                 # input to realign and reslice is normal runs
update_prefix "motion_correct"

get_stage_number "normalize"
if [ "$start_stage_num" -le "$stage_num" -a "$do_normalize" == 1 ]; then
    normalize "$runnums"
fi
if [ "$stop_stage_num" -le "$stage_num" ]; then
    exit;
fi
update_prefix "normalize"

get_stage_number "surf_project"
if [ "$start_stage_num" -le "$stage_num"  -a "$do_surf_project" == 1 ]; then
    surf_project "$runnums"
fi
if [ "$stop_stage_num" -le "$stage_num" ]; then
    exit;
fi
update_prefix "surf_project"

get_stage_number "smooth"
if [ "$start_stage_num" -le "$stage_num" ]; then
    # multiple smoothings are available
    if [ "$do_vol_smooth" == 1 ]; then
	vol_smooth "$runnums"
    fi

    if [ "$do_surf_vol_smooth" == 1 ]; then
	surf_vol_smooth "$runnums"
    fi

    if [ "$do_surf_smooth" == 1 ]; then
	surf_smooth "$runnums"
    fi
fi
if [ "$stop_stage_num" -le "$stage_num" ]; then
    exit;
fi
update_prefix "smooth"

echo prefix=$prefix

echo "Updating run nums for model: $model"
if [ "$model" -a "$same_runs_as_base_model" == 0 ]; then
    outlierfile=outliers_"$model".mat

# FIX: function this up. -twt
    if [ ! -e  scripts/func_runs_$model.txt ]; then
	summarize_dicomdir.sh "$dicom_dir"

	while [ 1 ] ; do
	    echo "enter the numbers of the functional runs for this model (p to print again): "
	    read runnums

	    case runnums in
		p ) ls nii;;
		* ) echo "read $runnums"
		    echo "enter 1 to accept, 0 to renter"
		    read again
		    if [ "$again" -eq 1 ]; then
			break;
		    fi
		    ;;
	    esac
	done
	echo $runnums > scripts/func_runs_$model.txt
    else
	runnums=`cat scripts/func_runs_$model.txt`
    fi
elif [ "$same_runs_as_base_model" == 1 ]; then
    echo "assuming runnums in scripts/func_runs.txt is correct"
    outlierfile=outliers.mat
else
    outlierfile=outliers.mat
fi
echo "Run nums for model \"$model\": $runnums"

echo `pwd`
get_stage_number "preoutlier_model"
if [ "$skip_spm_orth" == 1 ] ; then
    cp "$matlab_dir"/mod_spm_fMRI_design.m "$study_subjs_dir"/"$subj"/firstlevel_"$model"/outlier/spm_fMRI_design.m
else
    rm "$study_subjs_dir"/"$subj"/firstlevel_"$model"/outlier/spm_fMRI_design.m
fi
if [ "$start_stage_num" -le "$stage_num" -a "$do_preoutlier_model" == 1 ]; then
    echo computing the preoutlier model with model=$model...
    build_model "$runnums" "$model" outlier
fi
if [ "$stop_stage_num" -le "$stage_num" ]; then
    exit;
fi

echo "Outlier file: $outlierfile"

get_stage_number "outliers"
if [ "$start_stage_num" -le "$stage_num" -a "$do_outliers" == 1 ]; then
    # view artifacts using art
    if [ -e nii/$outlierfile -a "$skip_art_if_outliers_file_exists" == 1 ]; then
	echo "skipping ART because skip_art_if_outliers_file_exists is 1 "
    else
	art_batch "$runnums"
    fi
fi
if [ "$stop_stage_num" -le "$stage_num" ]; then
    exit;
fi

get_stage_number "view_funcruns"
if [ "$start_stage_num" -le "$stage_num" -a "$do_view_funcruns" == 1 ]; then
    view_funcruns "$runnums"
fi
if [ "$stop_stage_num" -le "$stage_num" ]; then
    exit;
fi

if [ "$skip_spm_orth" == 1 ] ; then
    cp "$matlab_dir"/mod_spm_fMRI_design.m "$study_subjs_dir"/"$subj"/firstlevel_"$model"/spm_fMRI_design.m
else
    rm "$study_subjs_dir"/"$subj"/firstlevel_"$model"/spm_fMRI_design.m
fi
get_stage_number "prepare_analysis"
if [ "$start_stage_num" -le "$stage_num"  -a "$do_prepare_analysis" == 1 ]; then
    echo preparing analysis with model=$model...

    if [ "$do_vol_estimate" == 1 ]; then
	build_model "$runnums" "$model" volume
    fi

    if [ "$do_surf_estimate" == 1 ]; then
	build_model "$runnums" "$model" surf lh
	build_model "$runnums" "$model" surf rh
    fi
fi
if [ "$stop_stage_num" -le "$stage_num" ]; then
    exit;
fi

# run first level
get_stage_number "run_firstlevel"
if [ "$start_stage_num" -le "$stage_num"  -a "$do_run_firstlevel" == 1 ]; then
    echo running first level with model=$model...

    if [ "$do_vol_estimate" == 1 ]; then
	run_firstlevel "$model" volume
    fi

    if [ "$do_surf_estimate" == 1 ]; then
	run_firstlevel "$model" surf lh
	run_firstlevel "$model" surf rh
    fi
fi
if [ "$stop_stage_num" -le "$stage_num" ]; then
    exit;
fi

# run contrasts
get_stage_number "run_contrasts"
if [ "$start_stage_num" -le "$stage_num"  -a "$do_run_contrasts" == 1 ]; then
    echo running contrasts with model=$model...

    if [ "$do_vol_estimate" == 1 ]; then
	run_contrasts "$model" "$est_model_dir" volume
    fi

    if [ "$do_surf_estimate" == 1 ]; then
	run_contrasts "$model" "$est_model_dir" surf lh
	run_contrasts "$model" "$est_model_dir" surf rh
    fi
fi
if [ "$stop_stage_num" -le "$stage_num" ]; then
    exit;
fi

#
get_stage_number "surf_paint"
if [ "$start_stage_num" -le "$stage_num"  -a "$do_surf_paint" == 1 ]; then
    echo running surf_paint with model=$model...
    surf_paint "$model"
fi
if [ "$stop_stage_num" -le "$stage_num" ]; then
    exit;
fi


