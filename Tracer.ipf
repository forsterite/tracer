#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma version=5.71
#pragma IgorVersion=8
#pragma ModuleName=tracer

// --------------------- Project Updater header ----------------------
// Project Updater can notify you when a new release of this project is 
// available. See https://www.wavemetrics.com/project/Updater
static constant kProjectID=342 // the project node on IgorExchange
static strconstant ksShortTitle="Tracer" // the project short title on IgorExchange

// https://www.wavemetrics.com/user/tony
// Please tell me when you find a bug, and let me know if you find this
// package useful or have suggestions for improvement.

// Changed behaviour for version >= 5 :

// Images are loaded to current data folder, not the package folder.
// Consequently Tracer can work with any images already present in
// current folder. The clear button still deletes only images loaded or
// created by Tracer.

// Either of the International Commission on Illumination (CIE) ΔE*ab
// (1994) or (2000) algorithms can be selected to quantify color
// difference.

// The interface for setting image scale has been tweaked. If you have
// identically sized images that should have the same scaling, you can
// right click to copy and paste image scaling.

// Command/ctrl-scroll to zoom. Shift key accelerates zoom.

// The image plot is no longer constrained to display in plan mode.

// 5.71 Includes version check
// 5.70 Includes Bezier to Wave conversion, contributed by Christian 
// Liebske, also includes some code by Jim Prouty. Reintroduces the 
// 'equal step' algorithm used in the first version of Tracer. New 
// 'folding panel' GUI. Pictures can be imported from clipboard - if 
// vector graphics are found in clipboard conversion to bitmap is 
// attempted. 
// 5.40 fixes bug that positioned setvars incorrectly on windows when
// large fonts are selected in system settings.
// 5.30 minor improvements to image setscale gui
// 5.20 non-fatal bug fix: reinitialising when tracer was already open
// deleted the package folder.
// 5.10 added ΔE*ab (2000) color difference algorithm
// Fixed a bug that prevented any pixel match when fuzzy slider is set to
// 'exact'. Even so, most images will require a non-zero fuzzy value for
// sucessful tracing.
// Rewrote the trace extraction code to improve efficiency
// 5.00 Major rewrite! Send me your bug reports...
// 4.20 A few minor changes, removed color-picker buttons because default
// color popup dialog has better selection tool with eye-dropper option.
// Added headers for Updater. The rest of this code could use a clean-up!
// 4.10 Uses /any flag with loadimage to load more image types
// 4.09 Bug fix: data folder not returned to starting one after quit on load.
// 4.08 Added headers for Project Updater.
// See http://www.igorexchange.com/project/Updater.
// 4.07 bug fix: tracing failed with error when starting with cursor on a
// non-trace pixel
// 4.06 Oct 9 2017 Smaller panel size + bug fix
// 4.05 Sep 28 2017 New option to force search for bounds of trace over
// some minimum range. Use this if you're trying to trace unfilled
// symbols.
// 4.04 Sep 22 2017 bug fix. allowing gaps could sometimes result in
// non-integer point numbers, leading to out-of-range errors.
// 4.03 6/23/17 create copies of image for editing
// 4.02 8/25/16 bug fix for editing RGBA images with an alpha
// (transparency) channel
// 4.01 6/20/16 fixed null string bug for empty display list at startup
// 4.00 4/12/16 Greyscale (2d) images worked in previous versions because
// Igor didn't complain about out of range errors, so layer 1 and 2
// values were the same as layer 0. Fixed my bad code and introduced some
// new features. Created a "pixel wiper" to assist with touching up image
// to help with trace extraction. Image is assumed to be 3D RGB or 2D
// greyscale wave. Now works with 24 or 48 bit images (8 or 16 bits per
// pixel). A future update for Igor 7/8/9 will use ScaleToIndex, maybe
// ImageInterpolate Warp...

// decrease kDoUpdateFrequency if you want to see the trace progression,
// increase if speed is too slow
// set to 0 for no interim DoUpdate
static constant kDoUpdateFrequency=30
static constant kEditCopies=1
static constant kUsageHints=1
static constant kColorDifferenceMethod=1 // 0 for CIE ΔE*ab (1994), 1 for CIEDE2000
static constant kPDFmin=500 // size in points for smallest dimension of bitmap created from vector graphics

menu "Data"
	"Tracer", /Q, tracer#Initialise()
end

// sets up package folder and creates globals
// then creates plot and panel
static function Initialise()
	
	int left = 200, top = 10
	GetWindow/Z TracerGraph wsizeRM
	if (v_flag == 0)
		left = v_left
		top = v_top
	endif
	
	DoWindow/K TracerGraph // start with a fresh window - this kills package folder too
	NewDataFolder/O root:Packages
	NewDataFolder/O root:Packages:Tracer
	DFREF dfr = root:Packages:Tracer
	Make/O/N=11 dfr:sliderTicks = p*5
	Make/O/T/N=11 dfr:sliderLabels /wave=sliderLabels
	sliderLabels[0] = "Exact"
	sliderLabels[10] = "Fuzzy"
	Display/K=1/N=TracerGraph/W=(left,top,left+400,top+300) as "Tracer Image"
	MakeTracerPanel()
end

static function MakeTracerPanel()
	DFREF dfr = root:Packages:Tracer
	DoWindow/K TracerPanel
	int panelwidth = 193, panelheight = 630-145 // control panel units
		
	NewPanel/K=2/N=TracerPanel/W=(panelwidth,0,0,panelheight)/HOST=TracerGraph/EXT=1 as "Tracer Controls"
	ModifyPanel/W=TracerGraph#TracerPanel, noEdit=1
	
	variable left=10, top=5, groupw=182, font=12
	
	// group 0: Image selection
	CheckBox chk0, win=TracerPanel, pos={0,top}, size={37,16}, value=1, mode=2, title="Image Selection", Proc=tracer#tracerCheckBoxes, fsize=font
	top += 15
	GroupBox grp_g0, win=TracerPanel, pos={left,top}, size={groupw,60}, title="", fsize=font
	top += 10
	Button btnLoad_g0, win=TracerPanel, pos={left+20,top}, size={60,20}, proc=tracer#tracerButtons, title="Load..."
	Button btnLoad_g0, win=TracerPanel, help={"Load an image to current data folder"}, fsize=font
	Button btnClean_g0, win=TracerPanel, pos={left+100,top}, size={60,20}, title="Clear...", Proc=tracer#tracerButtons
	Button btnClean_g0, win=TracerPanel, help={"Kill all images created by Tracer"}, fsize=font
	top += 25
	PopupMenu popImage_g0, win=TracerPanel, mode=1, Value=tracer#getImgList(), pos={left+10,top}, size={190,20}
	PopupMenu popImage_g0, win=TracerPanel, Proc=tracer#tracerPopMenu, title="Display: ", fsize=font
	PopupMenu popImage_g0, win=TracerPanel, help={"Display an image from current data folder"}
	top += 25
	
	// group 1: Set Scale
	CheckBox chk1, win=TracerPanel, pos={0,top}, size={37,16}, value=1, mode=2, title="Set Scale", Proc=tracer#tracerCheckBoxes, fsize=font
	top += 15
	GroupBox grp_g1, win=TracerPanel, pos={left,top}, size={groupw,40}, title="", fsize=font
	top += 10
	Button btnStartScale_g1, win=TracerPanel, pos={left+10,top}, size={45,20}, proc=tracer#tracerButtons, title="Show"//,fColor=(65535,65533,65534)
	Button btnStartScale_g1, win=TracerPanel, help={"Click to toggle setscale cursors"}, fsize=font
	CheckBox chkLogX_g1, win=TracerPanel, pos={left+60,top}, size={36,14}, proc=tracer#tracerCheckBoxes, title="Log X"
	CheckBox chkLogX_g1, win=TracerPanel, value=0, fsize=font, help={"Check for logarithmic X axis"}
	CheckBox chkLogY_g1, win=TracerPanel, pos={left+115,top}, size={36,14}, proc=tracer#tracerCheckBoxes, title="Log Y"
	CheckBox chkLogY_g1, win=TracerPanel, value=0, fsize=font, help={"Check for logarithmic Y axis"}
	top += 30
	
	// group 2: Output
	CheckBox chk2, win=TracerPanel, pos={0,top}, size={16,16}, value=1, mode=2, title="Output", Proc=tracer#tracerCheckBoxes, fsize=font
	top += 15
	GroupBox grp_g2, win=TracerPanel, pos={left,top}, size={groupw,60}, title="", fsize=font
	top += 10
	SetVariable svTraceName_g2, win=TracerPanel, pos={left+13,top}, size={145,16}, proc=tracer#tracerSetVar, title="Create:"
	SetVariable svTraceName_g2, win=TracerPanel, value=_STR:UniqueName("trace",1,0), fsize=font, help={"Set name for new trace"}
	top += 25
	CheckBox chkXY_g2, win=TracerPanel, pos={left+35,top}, size={58,14}, proc=tracer#tracerCheckBoxes, title="Prefer XY Data"
	CheckBox chkXY_g2, win=TracerPanel, value=0, help={"Create X and Y waves\rEqual step output is always XY"}, fsize=font
	top += 25
	
	// group 3: Extract
	CheckBox chk3, win=TracerPanel, pos={0,top}, size={37,16}, value=1, mode=2, title="Extract", Proc=tracer#tracerCheckBoxes, fsize=font
	top += 15
	GroupBox grp_g3, win=TracerPanel, pos={left,top}, size={groupw,215}, title="", fsize=font
	top += 10
	PopupMenu popTraceRGB_g3, win=TracerPanel, pos={left+15,top}, size={150,21}, proc=tracer#tracerPopMenu, title="Target color"//, bodywidth=50
	PopupMenu popTraceRGB_g3, win=TracerPanel, mode=1, popColor=(0,0,0), value=#"\"*COLORPOP*\"", fsize=font
	PopupMenu popTraceRGB_g3, win=TracerPanel, help={"Select \"Other...\", then the eye dropper to select color with mouse"}
	top += 25
	Slider sliderFuzzy_g3, win=TracerPanel, pos={left+13,top}, size={153,42},fSize=font-2
	Slider sliderFuzzy_g3, win=TracerPanel, limits={0,50,2.5}, vert=0
	Slider sliderFuzzy_g3, win=TracerPanel, userTicks={dfr:sliderTicks,dfr:sliderLabels}
	Slider sliderFuzzy_g3, win=TracerPanel, value=7.5, help={"Increase fuzziness to accept a greater range of pixel colors"}
	top += 50
	CheckBox chkXscan_g3, win=TracerPanel, mode=1, pos={left+20,top}, size={71,14}, proc=tracer#tracerCheckBoxes, title="X-scan", fsize=font
	CheckBox chkXscan_g3, win=TracerPanel, help={"Follow trace from left to right"}, value=1
	CheckBox chkStep_g3, win=TracerPanel, mode=1, pos={left+85,top}, size={71,14}, proc=tracer#tracerCheckBoxes, title="Equal Step", fsize=font
	CheckBox chkStep_g3, win=TracerPanel, help={"Follow trace with equal steps"}, value=0
	top += 25
	SetVariable svRange_g3, win=TracerPanel, pos={left+20,top}, size={140,16}, title="Minimum Range"
	SetVariable svRange_g3, win=TracerPanel, limits={0,Inf,0}, value=_NUM:0, fsize=font, bodyWidth=50
	SetVariable svRange_g3, win=TracerPanel, help={"Force search to consider all pixels within range when\rsearching for bounds of trace (default = 0)"}
	SetVariable svStepLen_g3, win=TracerPanel, pos={left+20,top}, size={140,16}, title="Step Length"
	SetVariable svStepLen_g3, win=TracerPanel, limits={5,Inf,0}, value=_NUM:15, fsize=font, bodyWidth=50
	SetVariable svStepLen_g3, win=TracerPanel, help={"Radius of sweep in pixels"}, disable=1
	top += 25
	SetVariable svJump_g3, win=TracerPanel, pos={left+20,top}, size={140,16}, title="Jump Threshold"
	SetVariable svJump_g3, win=TracerPanel, limits={0,Inf,0}, value=_NUM:100, fsize=font, bodyWidth=50
	SetVariable svJump_g3, win=TracerPanel, help={"Trace-colored pixels must be found within this range of\rprevious pixel to be considered part of continuous trace"}
	SetVariable svAngle_g3, win=TracerPanel, pos={left+20,top}, size={140,16}, title="Sweep Angle"
	SetVariable svAngle_g3, win=TracerPanel, limits={10,270,0}, value=_NUM:90, fsize=font, bodyWidth=50
	SetVariable svAngle_g3, win=TracerPanel, help={"Range of sweep in degrees"}, disable=1
	top += 25
	CheckBox chkGaps_g3, win=TracerPanel, pos={left+45,top}, size={71,14}, proc=tracer#tracerCheckBoxes, title="Allow Gaps", fsize=font
	CheckBox chkGaps_g3, win=TracerPanel, value=0, help={"Allow tracing to continue when no target pixel is found"}, disable=0
	SetVariable svMaxGap_g3, win=TracerPanel, pos={left+60,top}, size={100,16}, title="Maximum Gap"
	SetVariable svMaxGap_g3, win=TracerPanel, limits={0,Inf,0}, value=_NUM:50, fsize=font, bodyWidth=50
	SetVariable svMaxGap_g3, win=TracerPanel, help={"Maximum gap (in pixels) between segments.\rMust be greater than step length to allow gaps"}, disable=1
	top += 25
	Button btnExtract_g3, win=TracerPanel, pos={left+47,top}, size={86,20}, Proc=tracer#tracerButtons, title="Extract Trace", fsize=font, fColor=(57346,65535,49151), help={"Start tracing from cursor location"}
	top += 30
			
	// group 4: editing controls
	CheckBox chk4, win=TracerPanel, pos={0,top}, size={37,16}, value=0, mode=2, title="Edit", Proc=tracer#tracerCheckBoxes, fsize=font
	top += 15
	GroupBox grp_g4, win=TracerPanel, pos={left,top}, size={groupw,65}, title="", fsize=font, disable=1
	top += 10
	Button btnStartEditImg_g4, win=TracerPanel, pos={left+15,top}, size={70,20}, proc=tracer#tracerButtons, title="Edit image", fsize=font
	Button btnStartEditImg_g4, win=TracerPanel, help={"Edit the image to remove obstacles to tracing"}, disable=1
	Button btnStartEditTrace_g4, win=TracerPanel, pos={left+95,top}, size={70,20}, proc=tracer#tracerButtons, title="Edit trace", fsize=font
	Button btnStartEditTrace_g4, win=TracerPanel, help={"Adjust positions of points in traced curve after tracing"}, disable=1
	top += 25
	// hide some buttons behind the color popups
	Button btn1_g4, win=TracerPanel, pos={left+10-1,top-1}, size={50+2,20+2}, title="", Proc=tracer#tracerButtons, disable=1	//, fColor=(4147,26301,65419)//, fColor=(0xFFFF,1,1)
	Button btn2_g4, win=TracerPanel, pos={left+65-1,top-1}, size={50+2,20+2}, title="", Proc=tracer#tracerButtons, disable=1	//, fColor=(4147,26301,65419)
	Button btn3_g4, win=TracerPanel, pos={left+120-1,top-1}, size={50+2,20+2}, title="", Proc=tracer#tracerButtons, disable=1//, fColor=(4147,26301,65419)
	top+=1
	string strHelp = "Click on a popup or use keys 1, 2 and 3 to switch paint color\rSelect \"Other...\", then the eye dropper to select color with mouse"
	PopupMenu popRGB1_g4, win=TracerPanel, pos={left+10,top}, size={50,23}, proc=tracer#tracerPopMenu, title=""
	PopupMenu popRGB1_g4, win=TracerPanel, mode=1, popColor=(0x0000,0x0000,0x0000), value= #"\"*COLORPOP*\"", fsize=font, disable=1
	PopupMenu popRGB1_g4, win=TracerPanel, help={strHelp}
	PopupMenu popRGB2_g4, win=TracerPanel, pos={left+65,top}, size={50,23}, proc=tracer#tracerPopMenu, title=""
	PopupMenu popRGB2_g4, win=TracerPanel, mode=1, popColor=(0xFFFF,0x0000,0x0000), value= #"\"*COLORPOP*\"", fsize=font, disable=1	
	PopupMenu popRGB2_g4, win=TracerPanel, help={strHelp}
	PopupMenu popRGB3_g4, win=TracerPanel, pos={left+120,top}, size={50,23}, proc=tracer#tracerPopMenu, title=""
	PopupMenu popRGB3_g4, win=TracerPanel, mode=1, popColor=(0xFFFF,0xFFFF,0xFFFF), value= #"\"*COLORPOP*\"", fsize=font, disable=1	
	PopupMenu popRGB3_g4, win=TracerPanel, help={strHelp}
	SelectEditColor(1)
	top += 30
		
	top -= 60 // because group 4 controls are hidden
	// group 5: Bezier to wave
	CheckBox chk5, win=TracerPanel, pos={0,top}, size={37,16}, value=0, mode=2, title="Bezier to Wave", Proc=tracer#tracerCheckBoxes, fsize=font
	top += 15
	GroupBox grp_g5, win=TracerPanel, pos={left,top}, size={groupw,90}, title="", fsize=font, disable=1
	top += 10
	Button btnDrawMode_g5, win=TracerPanel, pos={left+10,top}, size={80,20}, title="Draw Mode", fsize=font, Proc=tracer#tracerButtons
	Button btnDrawMode_g5, help={"Activates polygon drawing mode.\rRight-click on polygon symbol and choose Draw Bezier"}, disable=1
	Button btnClearDrawLayer_g5, win=TracerPanel, pos={left+100,top}, size={45,20}, title="Clear", fsize=font, Proc=tracer#tracerButtons
	Button btnClearDrawLayer_g5, help={"Deletes Bezier from Drawing Layer UserFront"}, disable=1	
	Button btnHelp_g5, win=TracerPanel, pos={left+155,top+2}, size={15,15}, title="", Picture=Tracer#pHelp, labelBack=0
	Button btnHelp_g5, win=TracerPanel, Proc=tracer#tracerButtons, help={"Click for Bezier Instructions"}, focusRing=0, disable=1
	top += 25
	SetVariable svNPntSegm_g5, win=TracerPanel, pos={left+15,top}, size={140,16}, value=_NUM:20, title="Points per Segment"
	SetVariable svNPntSegm_g5, help={"Number of wave points per segment"}, fsize=font, limits={10,Inf,0}, disable=1
	top += 25
	Button btnExtractBezier_g5, win=TracerPanel, pos={left+43,top}, size={90,20},fColor=(57346,65535,49151)
	Button btnExtractBezier_g5, win=TracerPanel, title="Extract Bezier", fsize=font, Proc=tracer#tracerButtons, disable=1
	Button btnExtractBezier_g5, win=TracerPanel, help={"Turn Bezier curve into a wave"}
		
	// if we have already loaded an image, plot it
	ControlInfo/W=TracerGraph#TracerPanel popImage_g0
	wave/Z w_img=$S_Value
	if (WaveExists(w_img))
		PlotImage(w_img)
	endif
	
	SetWindow TracerGraph#TracerPanel userdata(version) = num2str(ProcedureVersion(""))
end

static function FillPanelStructure(STRUCT PanelStatusStructure &s)
	getControlValue("TracerGraph#TracerPanel", "popImage_g0", s.image)
	getControlValue("TracerGraph#TracerPanel", "chkLogX_g1", s.logX)
	getControlValue("TracerGraph#TracerPanel", "chkLogY_g1", s.logY)
	getControlValue("TracerGraph#TracerPanel", "chkXscan_g3", s.xscan)
	getControlValue("TracerGraph#TracerPanel", "chkStep_g3", s.step)
	getControlValue("TracerGraph#TracerPanel", "svStepLen_g3", s.steplen)
	getControlValue("TracerGraph#TracerPanel", "svAngle_g3", s.angle)
	getControlValue("TracerGraph#TracerPanel", "svMaxGap_g3", s.maxgap)
	getControlValue("TracerGraph#TracerPanel", "popTraceRGB_g3", s.trace)
	getControlValue("TracerGraph#TracerPanel", "sliderFuzzy_g3", s.fuzzy)
	getControlValue("TracerGraph#TracerPanel", "chkGaps_g3", s.gaps)
	getControlValue("TracerGraph#TracerPanel", "chkXY_g2", s.XY)
	getControlValue("TracerGraph#TracerPanel", "svJump_g3", s.jump)
	getControlValue("TracerGraph#TracerPanel", "svRange_g3", s.range)
	getControlValue("TracerGraph#TracerPanel", "svTraceName_g2", s.tracename)
	getControlValue("TracerGraph#TracerPanel", "popRGB1_g4", s.rgb1)
	getControlValue("TracerGraph#TracerPanel", "popRGB2_g4", s.rgb2)
	getControlValue("TracerGraph#TracerPanel", "popRGB3_g4", s.rgb3)
	getControlValue("TracerGraph#TracerPanel", "svNPntSegm_g5", s.segpnt)
	RGB2LAB(s.trace.rgb, s.targetLAB)
		
	wave/Z s.img = $s.image.sval
	if (WaveExists(s.img) == 0)
		string ImageNameString = StringFromList (0, ImageNameList("TracerGraph", ";" ))
		wave/Z s.img = ImageNameToWaveRef("TracerGraph", ImageNameString)
	endif
	if (WaveExists(s.img))
		s.imgsize.h = DimSize(s.img, 0)
		s.imgsize.v = DimSize(s.img, 1)
	endif
	DFREF dfr = root:Packages:Tracer
	wave/Z/SDFR=dfr s.wlogX = TracerLogX
	wave/Z/SDFR=dfr s.wlogY = TracerLogY
end

static structure PanelStatusStructure
	STRUCT ControlValueStructure image, logX, logY, trace, fuzzy, xscan, step, maxgap, gaps, XY, jump, range, steplen, angle, tracename, rgb1, rgb2, rgb3, segpnt
	STRUCT LABcolor targetLAB
	wave img, wlogX, wlogY
	STRUCT point imgsize
	// record image size?
	// and wave refs
endstructure

static structure ControlValueStructure
	int16 type
	string ctrlName
	variable value
	string sval
	STRUCT RGBColor rgb
	STRUCT RGBAColor rgba
	variable selcol
	string userdata
	int16 disable
endstructure

static function getControlValue(string win, string controlName, STRUCT ControlValueStructure &s)
	ControlInfo/W=$win $controlName
	s.ctrlName = controlName
	s.type = v_flag
	s.disable = V_disable
	switch (abs(V_Flag))
		case 3: // popup menu
			s.rgb.red = V_Red; s.rgb.green = V_Green; s.rgb.blue = V_Blue
			s.rgba.red = V_Red; s.rgba.green = V_Green; s.rgba.blue = V_Blue
			s.rgba.alpha = V_Alpha
		case 2: // CheckBox
		case 4: // valdisplay
		case 5: // SetVariable
		case 7: // slider
		case 8: // tab
			s.value = v_value
			s.sval = s_value
			s.userdata = S_UserData
			break
		case 11: // listbox
			s.value = v_value
			s.sval = s_value
			s.selcol = v_selcol
			s.userdata = S_UserData
			break
	endswitch
end

// get list of images in current datafolder
static function /S getImgList([int tracer])
	tracer = ParamIsDefault(tracer) ? 0 : tracer
	string ListOfImages = WaveList("*", ";", "DIMS:2") + WaveList("*", ";", "DIMS:3")
	if (tracer)
		int i
		for (i=ItemsInList(ListOfImages)-1;i>=0;i--)
			wave w = $StringFromList(i, ListOfImages)
			if (NumberByKey("TracerImage", note(w), "=") !=1 )
				ListOfImages = RemoveListItem(i, ListOfImages)
			endif
		endfor
		return ListOfImages
	endif
	if (strlen(ListOfImages) == 0)
		ListOfImages = "none;"
	endif
	return ListOfImages
end

static function tracerButtons(STRUCT WMButtonAction &s)
	
	if (s.eventCode != 2)
		return 0
	endif
	
	if (cmpstr(s.win, "TracerPanel")==0 && CheckUpdated(s.win, 1))
		return 0
	endif
	
	// handle buttons that should work without an image
	strswitch(s.ctrlName)
		case "btnLoad_g0":
			LoadTracerImage()
			return 0
		case "btnClean_g0":
			Cleanup()
			return 0
		case "btn1_g4":
		case "btn2_g4":
		case "btn3_g4":
			SelectEditColor(str2num((s.ctrlName)[3]))
			return 0
		case "btnHelp_g5":
			DisplayHelpTopic "Editing a Bezier Curve"
			return 0
		
		case "btnClearDrawLayer_g5":
			CL_ClearUserFront()
			return 0
		case "btnExtractBezier_g5":
			CL_ExtractBezier()
			return 0
		case "btnCancel":
			string/G root:Packages:Tracer:smouse = ""
			KillWindow/Z tpaneltemp
			return 0
	endswitch
	
	if (strlen(ImageNameList("TracerGraph", ";" )) == 0)
		DoAlert 0, "No image display!"
		return 0
	endif
		
	strswitch(s.ctrlName)
		case "btnExtract_g3":
			STRUCT PanelStatusStructure g
			fillPanelStructure(g)
			if (checkCursors(g) == 0)
				return 0
			endif
			if (g.xscan.value)
				ExtractTrace(g)
			else
				ExtractTraceEqualStep(g)
			endif
			break
		case "btnStartEditTrace_g4":
			EditTrace(1)
			break
		case "stopEditTrace":
			EditTrace(0)
			break
		case "btnStartEditImg_g4":
			EditImage(1)
			break
		case "btnStopEditImg_g4":
			EditImage(0)
			break
		case "btnStartScale_g1":
			ShowScaleCursors(1)
			break
		case "btnStopScale_g1":
			ShowScaleCursors(0)
			break
		case "btnDrawMode_g5":
			CL_SetUpDrawingMode()
			break
	endswitch
	return 0
end

static function SelectEditColor(int selection)
	int i
	Make/free wRGB={0,0,0}
	ControlInfo/W=TracerGraph#TracerPanel chk4
	
	for (i=1;i<4;i++)
		PopupMenu $"popRGB"+num2str(i)+"_g4", win=TracerPanel, disable=v_value ? 2*(selection!=i) : 1
		wRGB={0xE1FD,0xE204,0xE1F9}
		wRGB = selection == i ? 0xFFFF*(p==2) : wRGB
		Button $"btn"+num2str(i)+"_g4", win=TracerPanel, fColor=(wRGB[0],wRGB[1],wRGB[2])
		// this works for Igor Pro 9 on mac: the disabled popup is not opaque
	endfor
end

static function EditImage(int start)
	SetWindow TracerGraph hook(EditImgHook)=$""
	ControlInfo/W=TracerPanel btnStopEditImg_g4
	if(v_flag == 1)
		Button btnStopEditImg_g4, win=TracerGraph#TracerPanel, fColor=(0,0,0), title="Edit image", Rename=btnStartEditImg_g4
	endif
	if (start == 0)
		DoWindow/F TracerGraph
		return 0
	endif
	
	ControlInfo/W=TracerGraph#TracerPanel popImage_g0
	string strImage = S_Value
	wave/Z w_img = $strImage
	if (WaveExists(w_img) == 0)
		return 0
	endif
	
	int MakeCopy = kEditCopies, reedit = 0

	if (MakeCopy && cmpstr(strImage, GetUserData("TracerGraph","","editing"))==0)
		DoAlert 2, "continue editing " + strImage + "?\r\rNo will create a copy"
		if (V_flag == 3)
			return 0
		elseif (V_flag == 1)
			MakeCopy = 0 // don't make a copy this time
		endif
		reedit = 1
	endif
		
	if (kUsageHints && reedit==0)
		string cmd = "Warning: you are about to edit " + SelectString(MakeCopy, "", "a copy of ") + strImage
		#ifdef WINDOWS
		cmd += "\r\rHold ctrl and move mouse to paint in selected colour."
		#else
		cmd += "\r\rHold ⌘ and move mouse to paint in selected colour."
		#endif
		cmd += "\r\rClick on popup or use keys 1, 2, and 3 to select active color.\r\rExpand view for detailed editing.\r\rContinue?"
		DoAlert 1, cmd
		if (v_flag == 2)
			return 0
		endif
	endif
	
	if (MakeCopy)
		string newName = UniqueName(NameOfWave(w_img),1,0)
		Duplicate w_img $newName /wave=w
		note/K w ReplaceNumberByKey("TracerImage", note(w), 1, "=")
		
		// save current axis limits
		variable Lmin, Lmax, Bmin, Bmax
		GetAxis/W=TracerGraph/Q left
		Lmin = V_min; Lmax = V_max
		GetAxis/W=TracerGraph/Q bottom
		Bmin = V_min; Bmax = V_max
		
		PopupMenu popImage_g0, win=TracerGraph#TracerPanel, popmatch=NameOfWave(w)
		PlotImage(w)
		
		// restore axis limits
		if (Lmin > Lmax)
			SetAxis/R/W=TracerGraph left, Lmin, Lmax
		else
			SetAxis/W=TracerGraph left, Lmin, Lmax
		endif
		if (Bmin > Bmax)
			SetAxis/R/W=TracerGraph bottom, Bmin, Bmax
		else
			SetAxis/W=TracerGraph bottom, Bmin, Bmax
		endif
		strImage=newName
	endif
	
	DoWindow/F TracerGraph
	SetWindow TracerGraph hook(EditImgHook)=tracer#hookEditImg, userdata(editing)=strImage
	Button btnStartEditImg_g4, win=TracerGraph#TracerPanel, fcolor=(65535,0,0), title="Stop edit", Rename=btnStopEditImg_g4
	
	return 1
end

static function LoadTracerImage()
	
	LoadPICT/Q/Z "Clipboard"
	if (v_flag)
		DoAlert 2, "Do you want to load the image from the clipboard?"
		if (v_flag == 1) // yes
			ImportClip()
		endif
		if (v_flag != 2)
			return 0
		endif
	endif
	
	DFREF dfr = root:Packages:Tracer
	ImageLoad	/Q/T=any
	if (V_Flag == 0)
		return 0
	endif
	string imageStr = StringFromList(0, S_waveNames)
	string newImageStr = ParseFilePath(3, imageStr, ":", 0, 0)
	newImageStr = CleanupName(newImageStr,0)
	if (CheckName(newImageStr, 1))
		newImageStr = UniqueName(newImageStr, 1, 0)
	endif
	Rename $imageStr $newImageStr
	wave w_img = $newImageStr
	note w_img "TracerImage=1;"
	PlotImage(w_img)
	return 1
end

static function PlotImage(wave w_img)
	STRUCT PanelStatusStructure s
	FillPanelStructure(s)
	ShowScaleCursors(0)
	EditImage(0)
	EditTrace(0)
	ClearPlot()
	
	AppendImage/W=TracerGraph w_img
	string str = NameOfWave(w_img)
	
	SetAxis/A
	if (DimDelta(w_img, 0) < 0)
		SetAxis/A/R bottom
	endif
	if (DimDelta(w_img, 1) > 0)
		SetAxis/A/R left
	endif
	
	ModifyGraph width={Plan, abs(DimDelta(w_img, 1 )/ DimDelta(w_img, 0)), bottom, left}
	DoUpdate
	ModifyGraph width=0
	
	if (s.LogX.value || s.LogY.value)
		RebuildGraph()
	endif

	Cursor/N=1/I/W=TracerGraph/C=(65535,0,0)/P/S=1 A $str 0.15*s.imgsize.h, 0.5*s.imgsize.v
	Cursor/N=1/I/W=TracerGraph/C=(0,65535,0)/P/S=1 B $str 0.85*s.imgsize.h, 0.5*s.imgsize.v

	SetWindow TracerGraph hook(tracerHook)=tracer#hookTracer
	
	PopupMenu popImage_g0, win=TracerGraph#TracerPanel, Value=tracer#getImgList()
	PopupMenu popImage_g0, win=TracerGraph#TracerPanel, popmatch=NameOfWave(w_img)
	return 1
end

static function ClearPlot()
	string strImage="", strTrace=""
	do
		strImage = StringFromList (0, ImageNameList("TracerGraph", ";" ))
		RemoveImage/Z/W=TracerGraph $strImage // in Igor 9 can use /ALL flag
	while(strlen(strImage))
	do
		strTrace = StringFromList (0, TraceNameList("TracerGraph", ";" ,1))
		RemoveFromGraph/Z/W=TracerGraph $strTrace // in Igor 9 can use /ALL flag
	while(strlen(strTrace))
	return 1
end

static function Cleanup()
	string imageList = getImgList(tracer=1)
	if(ItemsInList(imageList)==0)
		return 0
	endif
	string cmd = "The following image waves will be deleted:"
	string tooMany = "\r*** TOO MANY TO LIST ***"
	string cont = "\r\rContinue?"
	string imageName
	int numImages = ItemsInList(imageList)
	int cmdLen = strlen(cmd) + strlen(tooMany) + strlen(cont)
	int i
	for (i=0;i<numImages;i+=1)
		imageName = StringFromList(i, imageList)
		// avoid too-long alert
		if ( cmdLen+strlen(imageName) >= 1023 )
			cmd += tooMany
			break
		endif
		cmd += "\r" + imageName
		cmdLen += strlen("\r" + imageName)
	endfor
	cmd += cont
	
	DoAlert 1, cmd
	if (V_Flag == 2)
		return 0
	endif
	ClearPlot()
	for (i=0;i<ItemsInList(imageList);i+=1)
		KillWaves/Z $StringFromList(i, imageList)
	endfor
	SetWindow TracerGraph userdata(imageList) = ""
	ControlUpdate/W=TracerGraph#TracerPanel popImage_g0
	return 1
end

// *** checkboxes ***
static function tracerCheckBoxes(STRUCT WMCheckboxAction &s)
	
	if (s.eventCode!=2)
		return 0
	endif
	
	if (CheckUpdated(s.win, 1))
		return 0
	endif
	
	int isStep
	if (cmpstr(s.ctrlName, "chkXscan_g3") == 0)
		isStep = 0 // clicked on X-scan
	else
		// clicked on some other CheckBox
		ControlInfo/W=$s.win chkStep_g3
		isStep = v_value
	endif
	
	int group = 0
	strswitch (s.ctrlName)
		case "chkLogX_g1":
			CheckBox chkXY_g2, win=TracerGraph#TracerPanel, value=s.checked, disable=2*(s.checked||isStep)
		case "chkLogY_g1": // logX or logY
			RebuildGraph()
			break
		case "chk5":
			group ++
		case "chk4":
			group ++
		case "chk3":
			group ++
		case "chk2":
			group ++
		case "chk1":
			group ++
		case "chk0":
					
			// enable or disable selected group of controls
			ModifyControlList ControlNameList(s.win, ";", "*_g"+num2str(group)) win=$s.win, disable=!s.checked
			
			// figure out the height required for the groupbox
			ControlInfo/W=$s.win $"grp_g"+num2str(group)
			variable HeightAdjustCPU = s.checked ? V_Height - 5 : -(V_Height - 5) // control panel units
			variable HeightAdjustPixels = cpu2pixels(heightAdjustCPU)
			// correct for panel expansion
			HeightAdjustPixels *= PanelResolution("TracerGraph#TracerPanel")/PanelResolution("")
							
			GetWindow $s.win wsize // points, local coordinates					
			variable WinHeightPixels = points2pixels(v_bottom - v_top)
			variable WinWidthPixels = points2pixels(V_right - V_left)

			// This seems to be wrong:
			// DisplayHelpTopic "MoveSubwindow"
			// When any value is greater than 1, coordinates are taken to be
			// fixed locations measured in points, or control panel units
			// for control panel hosts, relative to the top left corner of
			// the host frame.
			// it seems that pixels are required by MoveSubwindow and by ModifyControlList !!!!????
			
			// change panel height	
			MoveSubwindow/W=$s.win fnum=(WinWidthPixels, 0, 0, WinHeightPixels + HeightAdjustPixels)
			
			// Shift controls beneath this group up or down by height of
			// groupbox. This is weird, because we positioned these with
			// control panel units, but now we are using pixels to
			// reposition.
			int i
			for(i=group+1;i<6;i++)
				ModifyControlList ControlNameList(s.win, ";", "*"+num2str(i)) win=$s.win, pos+={0, HeightAdjustPixels}
			endfor
			
			if (group == 4 && s.checked)
				SelectEditColor(1)
			endif
					
			if (!(group == 3 && s.checked))
				// we're not enabling group 3
				break
			endif
		case "chkXscan_g3":
		case "chkStep_g3":
			// enable or disable controls in group 3 depending on which algorithm CheckBox is selected
			SetVariable svJump_g3, win=TracerPanel, disable=isStep
			SetVariable svRange_g3, win=TracerPanel, disable=isStep
			SetVariable svStepLen_g3, win=TracerPanel, disable=!isStep
			SetVariable svAngle_g3, win=TracerPanel, disable=!isStep
			SetVariable svMaxGap_g3, win=TracerPanel, disable=!isStep
			CheckBox chkGaps_g3, win=TracerPanel, disable=isStep
			CheckBox chkStep_g3, win=TracerPanel, value=isStep
			CheckBox chkXscan_g3, win=TracerPanel, value=!isStep
			break
	endswitch
	return 0
end

static function points2pixels(variable points)
	return points * ScreenResolution / 72
end

// control panel units:
// res=72: pixels or points
// res=96 or 84: pixels
// res>96: points
static function cpu2pixels(variable cpu)
	return ScreenResolution > 96 ? cpu * ScreenResolution / 72 : cpu
end

static function pixels2cpu(variable pixels)
	return ScreenResolution > 96 ? pixels * 72 / ScreenResolution : pixels
end

// rebuild graph without changing image
// allows switch between log and normal axes
static function RebuildGraph()
	DoWindow tracergraph
	if (V_Flag==0)
		return 0
	endif
	
	STRUCT PanelStatusStructure s
	fillPanelStructure(s)
	
	DFREF dfr = root:Packages:Tracer
	string strImage = StringFromList (0, ImageNameList("TracerGraph", ";"))
	wave/Z w_image = ImageNameToWaveRef("TracerGraph", strImage)
	if (WaveExists(w_image)==0)
		return 0
	endif
	
// save cursor positions and make sure they end up on the same pixels
	Make/free/N=6 csrP=NaN, csrQ=NaN
	Make/free/T csr={"A","B","C","D","E","F"}
	int i
	for(i=0;i<6;i++)
		if (cmpstr(StringByKey("TNAME", CsrInfo($csr[i])), strImage) == 0) // cursor is on image
			csrP[i] = pcsr($csr[i])
			csrQ[i] = qcsr($csr[i])
		endif
	endfor
		
	RemoveImage/W=tracergraph $strImage
	string ImageNote = note(W_Image)
	variable Xhigh, Xlow, Yhigh, Ylow
	
	if (s.LogX.value) // horizontal axis is logarithmic
		// figure out the X values at pixel edges 
		Make/O/N=(s.imgsize.h+1) dfr:TracerLogX /wave=TracerLogX
		Xhigh = NumberByKey("Xhigh", ImageNote)
		Xhigh = (numtype(Xhigh) == 2) ? 100 : Xhigh
		Xlow = NumberByKey("Xlow", ImageNote)
		Xlow = (numtype(Xlow) == 2) ? 1 : Xlow
		TracerLogX = alog(log(Xlow) + (p+0.5)/DimSize(TracerLogX,0)*(log(Xhigh)-log(Xlow)))
	endif
	if (s.LogY.value)
		Make/O/N=(s.imgsize.v + 1) dfr:TracerLogY /wave=TracerLogY
		Yhigh = NumberByKey("Yhigh", ImageNote)
		Yhigh = (numtype(Yhigh) == 2) ? 1 : Yhigh
		Ylow = NumberByKey("Ylow", ImageNote)
		Ylow = (numtype(Ylow) == 2) ? 100 : Ylow
		TracerLogY = alog(log(Ylow) + (DimSize(TracerLogY,0)-p-0.5)/DimSize(TracerLogY,0)*(log(Yhigh)-log(Ylow)))
	endif
	
	// need to specify this for Igor 7
	ModifyGraph/W=TracerGraph width=0
	
	AppendImage/W=TracerGraph w_image vs {dfr:$SelectString(s.LogX.value, "*", "TracerLogX"),dfr:$SelectString(s.LogY.value, "*", "TracerLogY")}
	if ((s.LogX.value && TracerLogX[0]>TracerLogX[1]) || (s.LogX.value==0 && DimDelta(w_image, 0) < 0))
		SetAxis/A/R bottom
	endif
	if ((s.LogY.value && TracerLogY[1]>TracerLogY[0]) || (s.LogY.value==0 && DimDelta(w_image, 1) > 0))
		SetAxis/A/R left
	endif
	ModifyGraph/W=TracerGraph log(left)=s.LogY.value, log(bottom)=s.LogX.value
		
	if (s.LogX.value==0 && s.LogY.value==0)
		ModifyGraph/W=TracerGraph width={Plan, abs(DimDelta(w_image, 1 )/ DimDelta(w_image, 0)) ,bottom,left}
		DoUpdate
	endif
	ModifyGraph/W=TracerGraph width=0
	
	for(i=0;i<6;i++)
		if (numtype(csrp[i]) == 0) // cursor was on image
			Cursor/I/W=TracerGraph/P $csr[i] $strImage csrp[i], csrq[i]
		endif
	endfor
	DoUpdate
	if (numtype(csrp[2]) == 0) // set scale is active
		STRUCT WMWinHookStruct swin
		swin.WinName = "TracerGraph"
		swin.eventcode = 6
		hookSetScale(swin)
	endif
	return 1
end

static function tracerSetVar(STRUCT WMSetVariableAction &s)
	if (s.eventCode == 8)
		if (CheckUpdated(s.win, 1))
			return 0
		endif
		SetVariable $s.ctrlName, win=$s.win, value=_STR:CleanupName(s.sval, 0)
	endif
	return 0
end

static function EditTrace(int start)
	GraphNormal/W=TracerGraph
	ControlInfo/W=TracerPanel StopEditTrace
	if(v_flag == 1)
		Button StopEditTrace, win=TracerGraph#TracerPanel, fColor=(0,0,0), title="Edit trace", Rename=btnStartEditTrace_g4
	endif
	if (start == 0)
		return 0
	endif
	string traceName = ""
	if (!(ItemsInList( TraceNameList("TracerGraph",";",1))))
		DoAlert 0, "No traces on graph"
		return 0
	endif
	Prompt traceName, "Trace to edit:"Popup, TraceNameList("TracerGraph",";",1)
	DoPrompt "Select trace to edit", traceName
	if (V_flag)
		return 0
	endif
	GraphWaveEdit/W=TracerGraph/M $traceName
	Button btnStartEditTrace_g4, win=TracerGraph#TracerPanel, fcolor=(65535,0,0), title="Stop edit", Rename=StopEditTrace
	return 1
end

static function tracerPopMenu(STRUCT WMPopupAction &s)
	
	if (s.eventCode != 2)
		return 0
	endif
	
	if (CheckUpdated(s.win, 0))
		return 0
	endif
	
	strswitch(s.ctrlName)
		case "popImage_g0":
	
			CheckBox chkLogX_g1 win=tracerPanel, value=0
			CheckBox chkLogY_g1 win=tracerPanel, value=0
			wave/Z w_img = $s.popStr
			if (WaveExists(w_img))
				PlotImage(w_img)
			endif
			break
		
		case "popTraceRGB_g3":
			ControlInfo/W=TracerGraph#TracerPanel $s.ctrlName
			Make/free wRGB = {V_Red,V_Green,V_Blue}
			wave/Z w_img = GetImageRef()
			if (WaveExists(w_img) && (DimSize(w_img,2)==0))
				wRGB = (V_Red+V_Green+V_Blue)/3
				PopupMenu $s.ctrlName, win=$s.win, popColor=(wRGB[0],wRGB[1],wRGB[2])
			endif
			// add selected color to the recent selections list for the image editing color pickers
			int i
			for (i=1;i<4;i++)
				ControlInfo/W=TracerGraph#TracerPanel $"popRGB"+num2str(i)+"_g4"
				PopupMenu $"popRGB"+num2str(i)+"_g4", win=$s.win, popColor=(wRGB[0],wRGB[1],wRGB[2])
				PopupMenu $"popRGB"+num2str(i)+"_g4", win=$s.win, popColor=(V_Red,V_Green,V_Blue)
			endfor
			break
		
		case "popRGB1_g4": // colour pickers
		case "popRGB2_g4":
		case "popRGB3_g4":

			break
	endswitch
	
	return 0
end

// make sure A and B cursors are in place
static function checkCursors(STRUCT PanelStatusStructure &s)
	if ( strlen(CsrInfo(A, "TracerGraph"))==0 || strlen(CsrInfo(B, "TracerGraph"))==0 )
		DoAlert 0, "Set cursors at start and end of trace"
		return 0
	elseif (cmpstr(CsrWave(A, "TracerGraph"), CsrWave(B, "TracerGraph")))
		DoAlert 0, "Cursors must be on the same image"
		return 0
	endif
		
	if (s.xscan.value && pcsr(A, "TracerGraph") > pcsr(B, "TracerGraph"))
		int tempP = pcsr(A, "TracerGraph"), tempQ=qcsr(A, "TracerGraph")
		Cursor/I/P/W=TracerGraph A $CsrWave(A, "TracerGraph") pcsr(B, "TracerGraph"), qcsr(B, "TracerGraph")
		Cursor/I/P/W=TracerGraph B $CsrWave(A, "TracerGraph") tempP, tempQ
	endif
	return 1
end

// this is where the magic happens
static function ExtractTrace(STRUCT PanelStatusStructure &s)
		
	if (WaveExists(s.img) == 0)
		return 0
	endif
	
	variable failX = NaN, lastY = NaN
	variable Yoffset = DimOffset(s.img, 1), Ydelta = DimDelta(s.img, 1)
	int lastP = NaN, lastQ = NaN
	int i, j, gap, minus, plus // j is DataWave point number, i is image row
	int startP = pcsr(A, "TracerGraph"), endP = pcsr(B, "TracerGraph")
	int startQ = qcsr(A, "TracerGraph"), endQ = qcsr(B, "TracerGraph")
	int qHigh = startQ, qLow = startQ, fail = 0
	variable numPoints = abs(endP - startP) + 1
	string cmd = ""
		
	int DoUpdateFrequency = kDoUpdateFrequency ? max(kDoUpdateFrequency, numPoints/50) : 0
	
	if (CheckName(s.tracename.sval, 1))
		DoAlert 1, s.tracename.sval + " already exists. Overwrite?"
		if (V_Flag == 2)
			return 0
		endif
	endif
	Make/O/N=(numPoints) $s.tracename.sval=NaN
	wave dataWave = $s.tracename.sval
	Print "Created wave " + NameOfWave(dataWave)
	
	RemoveFromGraph/Z/W=TracerGraph $NameOfWave(dataWave) // just in case
	if (s.XY.value)
		Make/O/N=(numPoints) $s.tracename.sval + "_X" = NaN
		wave dataXwave = $s.tracename.sval + "_X"
		dataXwave = s.logX.value ? s.wlogX[startP + p + 0.5] : IndexToScale(s.img, startP + p, 0)
		AppendToGraph/W=TracerGraph dataWave vs dataXwave
	else
		SetScale/I x, hcsr(A, "TracerGraph"), hcsr(B, "TracerGraph"), dataWave
		AppendToGraph/W=TracerGraph dataWave
	endif
	
	
	STRUCT RGBcolor RGB
	RGB = s.trace.rgb
	contrastingColor(RGB)
	ModifyGraph/W=TracerGraph rgb($NameOfWave(dataWave))=(rgb.red,rgb.green,rgb.blue)
	ModifyGraph/W=TracerGraph mode($NameOfWave(dataWave))=0, lsize($NameOfWave(dataWave))=2
	
		
	for(i=startP,j=0;i<=endP;i++,j++) // loop over rows of image / points of DataWave
		gap = 0
		if ((RGBgood(i, qHigh, s) == 0)) // non-trace pixel
			// expand to find a trace pixel
			// do this efficiently by minimizing calls to RGBgood
			plus = 1; minus = 1
			do
				plus = plus && qHigh<(s.imgsize.v - 1)
				if (plus)
					qHigh++
					if (RGBgood(i, qHigh, s))
						qLow = qHigh
						break
					endif
				endif
				minus = qLow>0
				if (minus)
					qLow--
					if (RGBgood(i, qLow, s))
						qHigh = qLow
						break
					endif
				endif
			while(plus || minus)
		endif
		
		// check that we're on a trace pixel now
		if (qHigh > qLow) // failed to find one
			if (s.gaps.value)
				gap = 1
			else
				fail += 1
				failX = s.XY.value ? dataXwave[j] : pnt2x(dataWave, j)
				break
			endif
		elseif (numtype(lastY) == 0 && abs(qHigh-lastQ) > s.jump.value)
			// found a pixel more than JumpThreshold pixels away from previous value
			if (s.gaps.value)
				gap = 1 // treat it as a gap
			elseif (fail == 0)
				fail = 2
				failX = s.XY.value ? dataXwave[j] : pnt2x(dataWave, j)
			endif
		endif

		if (gap) // j is datawave point number, i is img x pixel
			dataWave[j] = NaN
			// keep heading right until we hit the trace
			qHigh = numtype(lastY) == 0 ? lastQ : startQ
			qLow = qHigh
		else // not a gap
			if (s.range.value)
				qHigh += floor(s.range.value/2)
				qLow -= floor(s.range.value/2)
			endif
			qHigh = min(s.imgsize.v - 1, qHigh)
			qLow = max(0, qLow)
			
			plus = 1; minus = 1
			do // expand to find vertical limits of trace
				plus = plus && qHigh<(s.imgsize.v - 1) && RGBgood(i, qHigh+1, s)
				qHigh += plus
				minus = minus && qLow>0 && RGBgood(i, qLow-1, s)
				qLow -= minus
			while (plus || minus)
		
			if (s.range.value) // contract inward to find limits of trace
				plus = 1; minus = 1
				do
					minus = minus && RGBgood(i, qHigh, s)==0
					qHigh -= minus
					plus = plus && RGBgood(i, qLow, s)==0
					qLow += plus
				while (plus || minus)
			endif

			// record the mid-point
			lastQ = round((qHigh+qLow)/2)
			qLow  = lastQ
			qHigh = lastQ
			lastP = j
			lastY = (s.logY.value) ? s.wlogY[lastQ + 0.5] : Yoffset + Ydelta*lastQ
			dataWave[j] = lastY
		endif
		// allowing the doupdate can slow things down
		if ((DoUpdateFrequency) && mod(i, DoUpdateFrequency)==0) // sparse updating
			DoUpdate
		endif
	endfor
	DoUpdate
	
	if (fail==0 && numtype(lastY)==0 && (abs(endQ-lastQ)<10))
		Print "Trace extracted successfully"
	else
		if (numtype(lastY))
			sprintf cmd, "Could not find a trace-colored pixel."
			Print cmd
			cmd += "\rCheck trace color and color fuzziness settings."
		elseif (fail & 1)
			sprintf cmd, "Failed to follow trace at x = %g.", failX
			Print cmd
			cmd += "\rTry allowing gaps or adjusting color fuzziness setting."
		elseif (fail & 2)
			sprintf cmd, "May have failed to follow trace at x = %g.", failX
			Print cmd
			cmd += "\rTry allowing gaps or adjusting jump threshold\rand color fuzziness settings."
		else
			cmd = "Looks like trace failed."
			Print cmd
		endif
		sprintf cmd, "%s\r\rDelete %s?", cmd, NameOfWave(dataWave)
		DoAlert 1, cmd
		if (V_flag==1)
			RemoveFromGraph/W=TracerGraph $NameOfWave(dataWave)
			KillWaves/Z dataWave
			Print "Deleted wave " + s.tracename.sval
		endif
	endif
end



// use midpoint circle algorithm to choose end pixels
// do this once for a circle centred at 0,0 with the required radius.
// for chosen direction and sweep angles, calculate end points

// use Bresenham's line algorithm
// pixel density = numhits/numpixels in line

// could use an anti-aliased version and weight the hits.

// sweep, searching for new end pixel
// for each end pixel, calculate density of hits
// choose a direction based on max hits. if mutiple maxima, average the angle
// points ouside of image are misses.
// step one pixel in this direction (again using Bresenham).



static function ExtractTraceEqualStep(STRUCT PanelStatusStructure &s)
	
	if (WaveExists(s.img) == 0)
		return 0
	endif
	
	variable angle = s.angle.value/360*2*pi // maximum sweep
	int radius = s.steplen.value
	int maxGap = s.maxgap.value
			
	wave circle = CirclePointWave(0, 0, radius)
	#ifdef dev
	Duplicate/O circle, newcircle
	#else
	Duplicate/free circle, newcircle
	#endif

	int NumPntsCircle = DimSize(circle, 0)
	int numPntsArc =  NumPntsCircle * angle / (2*pi)
	numPntsArc += 1 - mod(numPntsArc, 2)
	int centrePnt = (numPntsArc-1)/2
	// wCircleIndex will contain the p values from wCircle that define an arc
	Make/O/free/N=(numPntsArc) wCircleIndex
	
	Make/free/N=(1,2) pntPQ = {{pcsr(A, "TracerGraph")},{qcsr(A, "TracerGraph")}}
	Make/free/N=(1,2) endPQ = {{pcsr(B, "TracerGraph")},{qcsr(B, "TracerGraph")}}
	
	variable direction // atan2(deltaY, deltaX), [-pi,pi]
	
	// click for start direction
	// use hookTracer to set globals and kill the pauseforuser panel
	
	GetWindow TracerGraph wsizeRM
	int top, left
	top = (v_top + v_bottom) / 2
	left = (v_left + v_right) / 2
	KillWindow/Z tpaneltemp
	NewPanel/W=(left,top,left+150,top+100)/K=2/N=tpaneltemp as "Click to continue"
	SetDrawEnv/W=tpaneltemp textrgb=(65535,0,0), textyjust=2
	DrawText/W=tpaneltemp 30,10,"click on the graph\rwindow to define\rthe start direction"
	Button btnCancel win=tpaneltemp, pos={45,60}, size={60,20}, proc=tracer#tracerButtons, title="Cancel"
	PauseForUser tpaneltemp, TracerGraph
	
	// On mouseup hookTracer puts mouse coordinates structure in global 
	// string smouse and ends PauseForUser. Cancel button clears string 
	// and ends PauseForUser.
	
	SVAR smouse = root:Packages:Tracer:smouse
	if (strlen(smouse) == 0)
		return 0
	endif
	
	STRUCT point mouse
	StructGet/S mouse, smouse
	STRUCT point pixel
	getImagePixel(pixel, mouse, s)
	// get point index of circle that defines our current direction of travel
	int pCircle = GetIndexOfClosestVector(circle, atan2(pixel.v-pntPQ[0][1], pixel.h-pntPQ[0][0]))
	
	int maxPoints = 1e3
	int DoUpdateFrequency = kDoUpdateFrequency ? max(kDoUpdateFrequency, maxPoints/50) : 0

	// check for valid pixel?
	
	if (CheckName(s.tracename.sval, 1))
		DoAlert 1, s.tracename.sval + " already exists. Overwrite?"
		if (V_Flag==2)
			return 0
		endif
	endif
	
	Make/O/N=(1) $s.tracename.sval = vcsr(A)
	wave dataWave = $s.tracename.sval
	Make/O/N=(1) $s.tracename.sval + "_X" = hcsr(A)
	wave dataXwave = $s.tracename.sval + "_X"
	printf "Created waves %s, %s\r" NameOfWave(dataWave), NameOfWave(dataXwave)
	
	RemoveFromGraph/Z/W=TracerGraph $NameOfWave(dataWave) // just in case
	AppendToGraph/W=TracerGraph dataWave vs dataXwave
	STRUCT RGBcolor RGB
	RGB = s.trace.rgb
	contrastingColor(RGB)
	ModifyGraph/W=TracerGraph rgb($NameOfWave(dataWave))=(rgb.red,rgb.green,rgb.blue)
	ModifyGraph/W=TracerGraph mode($NameOfWave(dataWave))=0, lsize($NameOfWave(dataWave))=2
		
	int i, j, pHigh, pLow, pMid, plus, minus, gap, resetwaves, fail, keys
	
	j = 1 // next point of datawave
	gap = 0
	resetwaves = 0
	fail = 4
	
	for (i=1;1;i++)
				
		// check that we haven't wandered outside of image
		if (pntPQ[0][0] != limit(pntPQ[0][0], 0, s.imgsize.h-1))
			fail = 4
			break
		endif
		if (pntPQ[0][1] != limit(pntPQ[0][1], 0, s.imgsize.v-1))
			fail = 4
			break
		endif
					
		// if end point within circle, add end point and stop
		if (sqrt((pntPQ[0][0]-endPQ[0][0])^2 + (pntPQ[0][1]-endPQ[0][1])^2) < radius)
			datawave[j]  = {s.logY.value ? s.wlogY[endPQ[0][1] + 0.5] : IndexToScale(s.img,endPQ[0][1],1)}
			dataXwave[j] = {s.logX.value ? s.wlogX[endPQ[0][0] + 0.5] : IndexToScale(s.img,endPQ[0][0],0)}
			j++
			fail = 0
			break
		endif
		
		// reset our field of view
		// consider pixels with coordinates taken from newcircle[p][], where p is found in wCircleIndex
		// wCircleIndex contains the point numbers of newcircle that define an arc,
		// with the centre point in the direction of travel
		newcircle = circle + pntPQ[0][q]
		wCircleIndex = pCircle - (numPntsArc-1)/2 + p
		wCircleIndex += NumPntsCircle * (wCircleIndex < 0)
		wCircleIndex = mod(wCircleIndex, NumPntsCircle)
		pHigh = centrePnt
		pLow = centrePnt
		
		if ((RGBgood(newcircle[wCircleIndex[centrePnt]][0], newcircle[wCircleIndex[centrePnt]][1], s)==0)) // non-trace pixel
			// expand to find a trace pixel
			// do this efficiently by minimizing calls to RGBgood
			plus = 1; minus = 1
			do
				plus = plus && pHigh<(numPntsArc-1)
				if (plus)
					pHigh++
					if (RGBgood(newcircle[wCircleIndex[pHigh]][0], newcircle[wCircleIndex[pHigh]][1], s))
						pLow = pHigh
						break
					endif
				endif
				minus = pLow > 0
				if (minus)
					pLow--
					if (RGBgood(newcircle[wCircleIndex[pLow]][0], newcircle[wCircleIndex[pLow]][1], s))
						pHigh = pLow
						break
					endif
				endif
			while(plus || minus)
		endif
			
		// check that we're on a trace pixel now
		if (pHigh > pLow) // failed to find one
			if (1) // (s.gaps.value)
				gap += 1
			else
				fail = 1
				break
			endif
		elseif (gap)// we found a valid pixel after a gap
			dataWave[j] = {NaN}
			dataXwave[j] = {NaN}
			j++
	
			resetwaves = 1
			gap = 0
		endif
		
		// we have either a trace pixel or a gap
	
		if (!gap) // j is datawave point number
			
			// expand to find limits of trace
			plus = 1; minus = 1
			do
				plus = plus && pHigh<(numPntsArc-1) && RGBgood(newcircle[wCircleIndex[pHigh+1]][0], newcircle[wCircleIndex[pHigh+1]][1], s)
				pHigh += plus
				minus = minus && pLow>0 && RGBgood(newcircle[wCircleIndex[pLow-1]][0], newcircle[wCircleIndex[pLow-1]][1], s)
				pLow -= minus
			while (plus || minus)
			
			// use midpoint to determine direction
			pMid = (pHigh + pLow)/2 // make sure this is an integer - don't want to average two values that wrap around the zeroth/end points....
			pCircle = wCircleIndex[pMid]
						
			pntPQ = newcircle[pCircle][q]
			dataWave[j] = {s.logY.value ? s.wlogY[newcircle[pCircle][1] + 0.5] : IndexToScale(s.img, pntPQ[0][1], 1)}
			dataXwave[j] = {s.logX.value ? s.wlogX[newcircle[pCircle][0] + 0.5] : IndexToScale(s.img, pntPQ[0][0], 0)}
			j++
			
			if (resetwaves)
				// record current direction
				direction = atan2(circle[pCircle][1], circle[pCircle][0])
				
				// reset circle and arc waves
				wave circle = CirclePointWave(0, 0, radius)
				#ifdef dev
				Duplicate/O circle, newcircle
				#else
				Duplicate/free circle, newcircle
				#endif
				NumPntsCircle = DimSize(circle, 0)
				numPntsArc =  NumPntsCircle * angle / (2*pi)
				numPntsArc += 1 - mod(numPntsArc, 2)
				centrePnt = (numPntsArc-1)/2
				Make/O/free/N=(numPntsArc) wCircleIndex
				pCircle = GetIndexOfClosestVector(circle, direction)
				resetwaves = 0
			endif
		else // must be a gap
			if ((gap + radius) > maxGap)
				fail = 1
				break
			endif
			
			// expand radius point by point
			direction = atan2(circle[pCircle][1], circle[pCircle][0])
			wave circle = CirclePointWave(0, 0, radius + gap)
			pCircle = GetIndexOfClosestVector(circle, direction)
			
			#ifdef dev
			Duplicate/O circle, newcircle
			#else
			Duplicate/free circle, newcircle
			#endif

			NumPntsCircle = DimSize(circle, 0)
			numPntsArc =  NumPntsCircle * angle / (2*pi)
			numPntsArc += 1 - mod(numPntsArc, 2)
			centrePnt = (numPntsArc-1)/2
			Make/O/free/N=(numPntsArc) wCircleIndex
			
		endif
						
		keys = GetKeyState(0)
		if (keys & 32) // esc
			break
		endif
					
		// allowing the doupdate can slow things down
		if ((DoUpdateFrequency) && mod(i, DoUpdateFrequency)==0) // sparse updating
			DoUpdate
		endif
		
		if (mod(i, maxPoints) == 0)
			DoUpdate
			DoAlert 1, num2str(i) + " iterations.\r\rContinue?"
			if (v_flag == 2) // no
				fail = 8
				break
			endif
		endif
	endfor
	
	DoUpdate
	
	string cmd = ""
	if (fail == 0)
		Print "Trace extracted successfully"
	else
		if (j == 1)
			sprintf cmd, "Could not find a trace-colored pixel."
			Print cmd
			cmd += "\rCheck trace color and color fuzziness settings."
		elseif (fail & 1)
			sprintf cmd, "Failed to follow trace at x = %g, y = %g", dataXwave[j-1], datawave[j-1]
			Print cmd
			cmd += "\rTry adjusting step size, angle, max gap\rand color fuzziness settings."
		elseif (fail & 2)
			sprintf cmd, "May have failed to follow trace at x = %g, y = %g", dataXwave[j-1], datawave[j-1]
			Print cmd
			cmd += "\rTry adjusting step size, angle, max gap\rand color fuzziness settings."
		else
			cmd = "Looks like trace failed."
			Print cmd
		endif
		sprintf cmd, "%s\r\rDelete %s?", cmd, NameOfWave(dataWave)
		DoAlert 1, cmd
		if (V_flag == 1)
			RemoveFromGraph/W=TracerGraph $NameOfWave(dataWave)
			KillWaves/Z dataWave
			Print "Deleted wave " + s.tracename.sval
		endif
	endif
end

// finds the point number of 2D wave circle closest to the vector defined by direction = atan2(v, h)
static function GetIndexOfClosestVector(wave wVectors, variable direction)
	Make/free/N=(DimSize(wVectors, 0)) wAngles = abs(atan2(wVectors[p][1], wVectors[p][0]) - direction)
	wAngles = wAngles > pi ? 2 * pi - wAngles : wAngles
	WaveStats/M=1/Q wAngles
	return v_minloc
end

//static function LineHitsDensity(variable x0, variable y0, variable x1, variable y1, wave wimg, STRUCT PanelStatusStructure &s, int radius)
//	wave pixels = LinePointWave(x0, y0, x1, y1)
//	int length = DimSize(pixels,0)
//
//	Make/N=(length)/free wHits = radius + 2 - p // linear distance weighting
////	make/N=(length)/free wHits = 1
//	int pLim = DimSize(wImg, 0) // this could be pre-calculated and stored in s
//	int qLim = DimSize(wImg, 1)
//	int total = sum(wHits)
//
//	wHits *= (pixels[p][0]>=0 && pixels[p][0]<pLim) && (pixels[p][1]>=0 && pixels[p][1]<qLim)
//	wHits *= wHits ? RGBmatch(wImg, pixels[p][0], pixels[p][1], s) : 0
//
//	return sum(wHits)/total
//end

//static function LineHitsDensity(variable x0, variable y0, variable x1, variable y1, wave wimg, STRUCT LABcolor &targetLAB, STRUCT PanelStatusStructure &s)
//	wave pixels = LinePointWave(x0, y0, x1, y1)
//	int length = dimsize(pixels,0)
//
////	make/N=(length)/free wHits = 11-p
//	make/N=(length)/free wHits = 11-p
//	int pLim = dimsize(wImg, 0) // this could be pre-calculated and stored in s
//	int qLim = dimsize(wImg, 1)
//	int total = sum(wHits)
//
//	wHits *= (pixels[p][0]>=0 && pixels[p][0]<pLim) && (pixels[p][1]>=0 && pixels[p][1]<qLim)
//	wHits *= wHits ? 100/RGBdifference(wImg, targetLAB, pixels[p][0], pixels[p][1], s) : 0
//
//	return sum(wHits)/total
//end


// determine whether w_img[pixelX][pixelY] is close enough in color to be considered a trace pixel
static function RGBgood(variable pixelX, variable pixelY, STRUCT PanelStatusStructure &s)
	
	if (pixelX<0 || pixelY<0 || pixelX>=s.imgsize.h || pixelY>=s.imgsize.v)
		return 0
	endif
	
	STRUCT RGBcolor RGBpixel
	getPixelRGB(RGBpixel, s.img, pixelX, pixelY)
	STRUCT LABcolor LABpixel
	RGB2LAB(RGBpixel, LABpixel)
	variable deltaE = kColorDifferenceMethod ? deltaE2000(s.targetLAB, LABpixel) : deltaE94(s.targetLAB, LABpixel)
	return floor(deltaE) <= s.fuzzy.value
end

// determine whether w_img[pixelX][pixelY] is close enough in color to be considered a trace pixel
static function RGBmatch(variable pixelX, variable pixelY, STRUCT PanelStatusStructure &s)
	STRUCT RGBcolor RGBpixel
	getPixelRGB(RGBpixel, s.img, pixelX, pixelY)
	STRUCT LABcolor LABpixel
	RGB2LAB(RGBpixel, LABpixel)
	variable deltaE = kColorDifferenceMethod ? deltaE2000(s.targetLAB, LABpixel) : deltaE94(s.targetLAB, LABpixel)
	if (floor(deltaE) <= s.fuzzy.value)
		return 1-deltaE/s.fuzzy.value
	endif
	return 0
end

static function getPixelRGB(STRUCT RGBcolor &RGB, wave w_img, int pixelP, int pixelQ)
	// work with 24 or 48 bit images (8 or 16 bits per pixel)
	variable bitdepth = (WaveType(w_img)&8) ? 257 : 1
	if (DimSize(w_img,2))
		RGB.red = w_img[pixelP][pixelQ][0]*bitdepth
		RGB.green = w_img[pixelP][pixelQ][1]*bitdepth
		RGB.blue = w_img[pixelP][pixelQ][2]*bitdepth
	else
		int grey = w_img[pixelP][pixelQ]*bitdepth
		RGB.red = grey
		RGB.green = grey
		RGB.blue = grey
	endif
	return 1
end

// write RGB values to a pixel, or a bunch of pixels,
// depending on how zoomed-in we are on the image
static function writePixelRGB(STRUCT RGBcolor &RGB, wave w_img, STRUCT point &pixel, STRUCT PanelStatusStructure &s, variable brush)
	DFREF dfr = root:Packages:Tracer
	
	if (pixel.h<0 || pixel.v<0 || pixel.h>=s.imgsize.h || pixel.v>=s.imgsize.v)
		return 0
	endif
	int pmin = pixel.h - brush/2, qmin = pixel.v - brush/2
	int pmax = pixel.h + brush/2, qmax = pixel.v + brush/2
	pmin = max(0, min(pmin, s.imgsize.h-1))
	pmax = max(0, min(pmax, s.imgsize.h-1))
	qmin = max(0, min(qmin, s.imgsize.v-1))
	qmax = max(0, min(qmax, s.imgsize.v-1))
	
	// figure out colour depth
	// work with 24 or 48 bit images (8 or 16 bits per pixel)
	Make/free w={RGB.red,RGB.green,RGB.blue}
	w /= WaveType(w_img)&8 ? 257 : 1
	
	if (DimSize(w_img,2))
		w_img[pmin,pmax][qmin,qmax][0,2] = w[r]
	else
		w_img[pmin,pmax][qmin,qmax] = w[0]
	endif
	
	return 1
end

// figure out the appropriate brush stroke for image editing
static function brushStroke(wave w_img, STRUCT PanelStatusStructure &s)
	DFREF dfr = root:Packages:Tracer
	variable hpoints, vpoints
	GetAxis/W=TracerGraph/Q bottom
	int pmin, pmax
	if (s.logX.value)
		wave TracerLogX = dfr:TracerLogX
		pmax = BinarySearch(TracerLogX, v_max)
		pmax = pmax<0 ? (pmax==-2 ? numpnts(TracerLogX)-1 : 0) : pmax
		pmin = BinarySearch(TracerLogX, v_min)
		pmin = pmin<0 ? (pmin==-2 ? numpnts(TracerLogX)-1 : 0) : pmin
		hpoints = abs(pmax - pmin)
	else
		hpoints = abs(scaleToIndex(w_img, v_max, 0) - scaleToIndex(w_img, v_min, 0))
	endif
	GetAxis/W=TracerGraph/Q left
	if (s.logY.value)
		wave TracerLogY = dfr:TracerLogY
		pmax = BinarySearch(TracerLogY, v_max)
		pmax = pmax<0 ? (pmax==-2 ? numpnts(TracerLogY)-1 : 0) : pmax
		pmin = BinarySearch(TracerLogX, v_min)
		pmin = pmin<0 ? (pmin==-2 ? numpnts(TracerLogY)-1 : 0) : pmin
		vpoints = abs(pmax - pmin)
	else
		vpoints = abs(scaleToIndex(w_img, v_max, 1) - scaleToIndex(w_img, v_min, 1))
	endif
	GetWindow tracergraph gsize
	return 6 * min(hpoints/(v_right-v_left), vpoints/(v_bottom-v_top)) // 6 x image pixels per window point
end

// hook function to deal with image editing
static function hookEditImg(STRUCT WMWinHookStruct &s)
	
	
//	// doesn't work when mouse button is down
//	key = GetKeyState(0)
//
////	if (key&4) // shift key allows alt-to-drag behaviour
////		return 0
////	endif
//
//	if (key&1) // cmd/ctrl
//		s.doSetCursor = 1
//		s.cursorCode = 20
////	elseif (key&2) // option/alt
////		s.doSetCursor = 1
////		s.cursorCode = 19
//	endif
	
	if (s.eventMod & 8) // cmd/ctrl
		s.doSetCursor = 1
		s.cursorCode = 20
	endif
		
	if (! (s.eventCode==3 && s.eventMod==9) ) // mousedown, ctrl
		return 0
	endif
	
	STRUCT PanelStatusStructure g
	fillPanelStructure(g)

	DFREF dfr = root:Packages:Tracer
	wave w_img = GetImageRef()
	variable v_X, v_Y, p_X, p_Y
	
	STRUCT RGBcolor RGB
	if (g.rgb1.disable == 0)
		RGB = g.rgb1.rgb
	elseif (g.rgb2.disable == 0)
		RGB = g.rgb2.rgb
	elseif (g.rgb3.disable == 0)
		RGB = g.rgb3.rgb
	else
		return 0
	endif

	int ctrl = 1
	int keys, shift

	int mousebutton
	variable brush = brushStroke(w_img, g)
	int oldLeft = s.mouseLoc.h, oldTop = s.mouseLoc.v
	int horiz = 0, vert = 0
	for (;ctrl;)
		keys = GetKeyState(0)
		GetMouse/W=$s.WinName
		mousebutton = V_flag & 1
		if (keys & 4) // shift
			if ((horiz + vert) == 0)
				if (abs(v_left-oldLeft) > abs(v_top-oldTop))
					vert = 1
				elseif (abs(v_top-oldTop) > abs(v_left-oldLeft))
					horiz = 1
				endif
			endif
			if (vert)
				v_top = oldTop
			elseif (horiz)
				v_left = oldLeft
			endif
		else
			horiz = 0
			vert = 0
		endif
				
		if (v_left==oldLeft && v_top==oldTop)
			continue
		endif
		
		oldLeft = v_left
		oldTop = v_top
		
		ctrl = keys & 1
		if (!(mousebutton && ctrl))
			continue
		endif
		
		STRUCT point mouse
		STRUCT point pixel
		mouse.h = v_left
		mouse.v = v_top
		getImagePixel(pixel, mouse, g)
			
		if (writePixelRGB(RGB, w_img, pixel, g, brush))
			DoUpdate
		endif
	endfor
	return 0
end


static function getImagePixel(STRUCT point &pixel, STRUCT point &mouse, STRUCT PanelStatusStructure &g)
	variable v_X = AxisValFromPixel("TracerGraph", "bottom", mouse.h )
	variable v_Y = AxisValFromPixel("TracerGraph", "left", mouse.v )
		
	if (g.logY.value)
		pixel.v = BinarySearch(g.wlogY, v_Y)
	else
		pixel.v = scaleToIndex(g.img, v_Y, 1)
	endif

	if (g.logX.value)
		pixel.h = BinarySearch(g.wlogX, v_X)
	else
		pixel.h = scaleToIndex(g.img, v_X, 0)
	endif
end


// hook function to deal with cursors
static function hookTracer(STRUCT WMWinHookStruct &s)
	
	// this section replicates scroll-to-zoom behaviour, hardwired to left/bottom axes
	if (s.eventCode==22 && s.eventMod&8) // mousewheel/touchpad + control/command key
		GetWindow $s.WinName hook(hScrollToZoom)
		if (strlen(s_value))
			return 0
		endif
		Make/D/free/N=3 wH, wV // free waves to hold axis minimum, maximum, and axis value for mouse location
		GetAxis/W=$s.WinName/Q bottom
		if (v_flag)
			return 0
		endif
		int logH = NumberByKey("log(x)", AxisInfo(s.WinName, "bottom"),"=")
		wH = {v_min, v_max, AxisValFromPixel(s.WinName, "bottom", s.mouseLoc.h)}
		wH = logH ? log(wH) : wH
		GetAxis/W=$s.WinName/Q left
		if (v_flag)
			return 0
		endif
		wV = {v_min, v_max, AxisValFromPixel(s.WinName, "left", s.mouseLoc.v)}
		int logV = NumberByKey("log(x)", AxisInfo(s.WinName, "left"),"=")
		wV = logV ? log(wV) : wV
		// shift key is accelerator
		s.wheelDy = s.wheelDy == 0 ? s.wheelDx : s.wheelDy
		variable expansion = s.eventMod&2 ? 1 - s.wheelDy / 5 : 1 - s.wheelDy / 50
		wH[0,1] = wH[2] - (wH[2] - wH[p]) * expansion
		wV[0,1] = wV[2] - (wV[2] - wV[p]) * expansion
		wH = logH ? alog(wH) : WH
		wV = logV ? alog(wV) : wV
		if (wH[1] > wH[0])
			SetAxis/W=$s.WinName bottom, wH[0], wH[1]
		else
			SetAxis/R/W=$s.WinName bottom, wH[0], wH[1]
		endif
		if (wV[1] > wV[0])
			SetAxis/W=$s.WinName left, wV[0], wV[1]
		else
			SetAxis/R/W=$s.WinName left, wV[0], wV[1]
		endif
		return 0
	endif
		
	if (s.eventCode == 10) // menu
		if (stringmatch(s.menuItem, "Paste"))
			return ImportClip()
		endif
	endif
	
	if (s.eventCode == 11 ) // keyboard
		if (s.keycode>48 && s.keycode<52)
			GetWindow tracergraph hook(EditImgHook)
			if (strlen(s_value))
				SelectEditColor(s.keycode-48) // 1, 2, or 3
				return 1
			endif
		endif
	endif
	
	if (s.eventCode == 7) // cursor moved
		wave/Z w_img=GetImageRef()
		if (WaveExists(w_img)==0)
			return 0
		endif

		STRUCT RGBcolor RGB
		if (GrepString(s.cursorName, "A|B") && WaveRefsEqual(w_img, CsrWaveRef($s.cursorName,"TracerGraph")))
			// update cursor colour
			getPixelRGB(RGB, w_img, pcsr($s.cursorName, "TracerGraph"), qcsr($s.cursorName, "TracerGraph"))
			contrastingColor(RGB)
			Cursor/M/C=(RGB.red,RGB.green,RGB.blue)/W=TracerGraph $s.cursorName
			
			// if rgb good, change appearance of popupmenu? // make a quicker 'PixelGood' function
						
		endif
	endif
	
	if (s.eventcode == 5 && WinType("tpaneltemp")==7) // mouseup
		DFREF dfr = root:Packages:Tracer
		string/G dfr:smouse = ""
		StructPut/S s.mouseloc dfr:smouse
		variable/G dfr:mouseh = s.mouseloc.h
		variable/G dfr:mousev = s.mouseloc.v
		KillWindow/Z tpaneltemp
	endif
	
	if (s.eventCode == 2) // kill
		KillDataFolder/Z root:packages:tracer:
	endif

	return 0
end

static function ImportClip()
		
	LoadPICT/Q/Z "Clipboard"
	if(v_flag == 0)
		return 0
	endif
	
	LoadPICT/Q/O "Clipboard", TracerImageTemp
	if (V_flag == 0)
		return 0
	endif
	
	string strPict = StringByKey("NAME", S_info)
	string strType = StringByKey("TYPE", S_info)
	variable width = NumberByKey("PHYSWIDTH", S_info)
	variable height = NumberByKey("PHYSHEIGHT", S_info)
	int heightPix = NumberByKey("HEIGHT", S_info)
	int widthPix = NumberByKey("WIDTH", S_info)
	
	wave/Z w_img = $""
	
	string ext = ""
	strswitch (strType) // this is redundant because the the OS puts a png in the clip for all of these image types
		case "JPEG":
			ext = ".jpg"
			break
		case "TIFF":
			ext = ".tif"
			break
		case "PNG":
			ext = ".png"
			break
	endswitch
	
	NewPath/O/Q/Z TracerPathTemp, SpecialDirPath("Temporary", 0, 0, 0)
	
	if (strlen(ext))
		SavePICT/Z/O/PICT=$strPict/P=TracerPathTemp
		
		#ifdef dev
		Print "found " + ext + " in clipboard"
		#endif
		
	else
				
		// create a hidden graph as a canvas for pict, match aspect ratio
		variable gheight = max(kPDFmin/width*height, kPDFmin) // vertical size of graph in points
		variable scale = gheight / height
		variable gwidth = scale * width
		
		KillWindow/Z TracerGraphTemp
		Display/W=(0, 0, gwidth, gheight)/N=TracerGraphTemp/hide=1
		DrawPICT/W=TracerGraphTemp 0, 0, scale, scale, $strPict
		
		// export the graph window as png
		ext = ".png"
		SavePICT/E=-5/B=288/WIN=TracerGraphTemp/O/P=TracerPathTemp as strPict+ext
		
		#ifdef dev
		Print "found pdf in clipboard"
		printf "PHYSHEIGHT=%g, HEIGHT=%g, PHYSWIDTH=%g, gheight=%g\r", height, heightPix, width, gheight
		#endif
				
	endif

	if (v_flag == 0) // savePICT success
		ImageLoad/Q/P=TracerPathTemp/N=TracerImage strPict+ext
		wave/Z w_img = $StringFromList(0, S_waveNames)
		#ifdef dev
		Print "loaded temporary file "	+ S_path + S_fileName
		#endif
	endif
	
	// clean up
	KillWindow/Z TracerGraphTemp
	KillPICTs/Z $strPict
	KillPath/Z TracerPathTemp

	if (WaveExists(w_img))
		note w_img "TracerImage=1;"
		PopupMenu popImage_g0, win=TracerPanel, popmatch=StringFromList(0, S_waveNames)
		CheckBox chkLogX_g1 win=tracerPanel, value=0
		CheckBox chkLogY_g1 win=tracerPanel, value=0
		PlotImage(w_img)
	endif

	return 0
end

static function contrastingColor(STRUCT RGBcolor &RGB)
	STRUCT HSLcolor HSL
	RGB2HSL(RGB, HSL)
	if(HSL.S<0.3)
		RGB.red=65535; RGB.green=0; RGB.blue=0
		return 1
	endif
	variable hue = round(6*HSL.H)
	hue -= 6*(hue>5)
	switch (hue)
		case 0: // red
			RGB.red=0x0000; RGB.green=0xFFFF; RGB.blue=0xFFFF // cyan
			break
		case 1: // yellow
			RGB.red=0x0000; RGB.green=0x0000; RGB.blue=0xFFFF // blue
			break
		case 2: // green
			RGB.red=0xFFFF; RGB.green=0x0000; RGB.blue=0xFFFF // magenta
			break
		case 3: // cyan
			RGB.red=0xFFFF; RGB.green=0x0000; RGB.blue=0x0000 // red
			break
		case 4: // blue
			RGB.red=0xFFFF; RGB.green=0xFFFF; RGB.blue=0x0000 // yellow
			break
		case 5: // magenta
			RGB.red=0x0000; RGB.green=0xFFFF; RGB.blue=0x0000 // lime
			break
	endswitch
	return 1
end

// see easyrgb.com
// input is 16 bit sRGB
static function RGB2HSL(STRUCT RGBcolor &rgb, STRUCT HSLcolor &hsl)
	// R, G and B input range = 0 - 65535
	// H, S and L output range = 0 - 1
	variable red = rgb.red/0xFFFF, green = rgb.green/0xFFFF, blue = rgb.blue/0xFFFF
	variable var_Min = min(red,green,blue), var_Max = max(red,green,blue)
	variable del_Max = var_Max - var_Min
	
	hsl.L = (var_Max + var_Min) / 2
	if (del_Max == 0) // grey
	    hsl.H = 0
	    hsl.S = 0
	else // Chromatic data
		hsl.S = (hsl.L < 0.5) ? del_Max/(var_Max + var_Min) : del_Max/(2 - var_Max - var_Min)
		
		variable del_R = ( (var_Max - red)/6 + del_Max/2 ) / del_Max
		variable del_G = ( (var_Max - green)/6 + del_Max/2 ) / del_Max
		variable del_B = ( (var_Max - blue)/6 + del_Max/2 ) / del_Max
		
		if(red == var_Max)
			hsl.H = del_B - del_G
		elseif (green == var_Max)
			hsl.H = (1/3) + del_R - del_B
		elseif (blue == var_Max)
			hsl.H = (2/3) + del_G - del_R
		endif
		hsl.H += (hsl.H < 0)
		hsl.H -= (hsl.H > 1)
	endif
	return 1
end

static structure XYZcolor
	float X, Y, Z
endstructure

static structure LABcolor
	float L, a, b
endstructure

static structure HSLcolor
	float H, S, L
endstructure

// input is 16 bit sRGB
static function RGB2XYZ(STRUCT RGBcolor &rgb, STRUCT XYZcolor &xyz)
	// X, Y and Z output refer to a D65/2° standard illuminant.
	Make/free w={rgb.red, rgb.green, rgb.blue}
	w /= 0xFFFF
	w = w > 0.04045 ? ((w + 0.055) / 1.055)^2.4 : w / 12.92
	w *= 100
	xyz.X = w[0] * 0.4124 + w[1] * 0.3576 + w[2] * 0.1805
	xyz.Y = w[0] * 0.2126 + w[1] * 0.7152 + w[2] * 0.0722
	xyz.Z = w[0] * 0.0193 + w[1] * 0.1192 + w[2] * 0.9505
end

static function XYZ2LAB(STRUCT XYZcolor &xyz, STRUCT LABcolor &Lab)
	// reference values for D65/2° standard illuminant.
	Make/free w={xyz.X, xyz.Y, xyz.Z}, XYZref={95.047,100,108.883}
	w /= XYZref
	w = (w > 0.008856) ? w^(1/3) : 7.787 * w + (16 / 116)
	Lab.L = (116 * w[1]) - 16
	Lab.a = 500 * (w[0] - w[1])
	Lab.b = 200 * (w[1] - w[2])
end

// input is 16 bit sRGB
static function RGB2LAB(STRUCT RGBcolor &rgb, STRUCT LABcolor &Lab)
	// X, Y and Z output refer to a D65/2° standard illuminant.
	Make/free w={rgb.red, rgb.green, rgb.blue}
	w /= 0xFFFF
	w = w > 0.04045 ? ((w + 0.055) / 1.055)^2.4 : w / 12.92
	w *= 100
	Make/free/N=3 xyz
	xyz[0] = w[0] * 0.4124 + w[1] * 0.3576 + w[2] * 0.1805
	xyz[1] = w[0] * 0.2126 + w[1] * 0.7152 + w[2] * 0.0722
	xyz[2] = w[0] * 0.0193 + w[1] * 0.1192 + w[2] * 0.9505
	Make/free XYZref={95.047,100,108.883}
	w = xyz / XYZref
	w = (w > 0.008856) ? w^(1/3) :  7.787 * w + (16 / 116)
	Lab.L = (116 * w[1]) - 16
	Lab.a = 500 * (w[0] - w[1])
	Lab.b = 200 * (w[1] - w[2])
end

// see https://en.wikipedia.org/wiki/Color_difference
static function deltaE94(STRUCT LABcolor &Lab1, STRUCT LABcolor &Lab2)
	variable kL = 1, K1 = 0.045, K2 = 0.015
	variable C1 = sqrt(Lab1.a^2 + Lab1.b^2)
	variable C2 = sqrt(Lab2.a^2 + Lab2.b^2)
	variable deltaL = Lab2.L - Lab1.L
	variable deltaC = C2 - C1
	variable deltaH = (Lab2.a - Lab1.a)^2 + (Lab2.b-Lab1.b)^2 - deltaC^2
	deltaH = deltaH > 0 ? sqrt(deltaH) : 0
	variable SL = 1
	variable SC = 1 + ( K1 * C1 )
	variable SH = 1 + ( K2 * C1 )
	return sqrt( (deltaL/kL/SL)^2 + (deltaC/SC)^2 + (deltaH/SH)^2 )
end

// see https://en.wikipedia.org/wiki/Color_difference
static function deltaE2000(STRUCT LABcolor &Lab1, STRUCT LABcolor &Lab2)
	variable kL = 1, kC = 1, kH = 1 // Weight factors
	variable deltaL = Lab2.L - Lab1.L
	variable Lbar = (Lab1.L + Lab2.L) / 2
	variable C1a = sqrt(Lab1.a^2 + Lab1.b^2)
	variable C2a = sqrt(Lab2.a^2 + Lab2.b^2)
	variable Cbar = (C1a + C2a)/2
	variable a1prime = Lab1.a + Lab1.a/2 * (1 - sqrt(Cbar^7/(Cbar^7+25^7)))
	variable a2prime = Lab2.a + Lab2.a/2 * (1 - sqrt(Cbar^7/(Cbar^7+25^7)))
	variable C1prime = sqrt(a1prime^2 + Lab1.b^2)
	variable C2prime = sqrt(a2prime^2 + Lab2.b^2)
	variable Cprimebar = (C1prime + C2prime)/2
	variable deltaCprime = C2prime - C1prime
	variable h1prime = Lab1.b==a1prime ? 0 : atan2(Lab1.b, a1prime)
	h1prime += 2*Pi*(h1prime<0)
	variable h2prime = Lab2.b==a2prime ? 0 : atan2(Lab2.b, a2prime)
	h2prime += 2*Pi*(h2prime<0)
	variable deltaHprime = h2prime-h1prime // small h
	deltaHprime += (abs(h1prime-h2prime)) <= Pi ? 0 : 2*Pi*(1-2*(h2prime>h1prime)) // small h
	deltaHprime = 2*sqrt(C1prime*C2prime)*sin(deltahprime/2) // large H
	variable Hprimebar = (h1prime + h2prime)/2
	Hprimebar += (abs(h1prime-h2prime)) <= Pi ? 0 : Pi*(1-2*((h1prime+h2prime) >= (2*Pi)))
	variable T = 1 - 0.17 * cos(Hprimebar - Pi/6) + 0.24 * cos(2*Hprimebar) + 0.32 * cos(3*Hprimebar + 6*Pi/180) - 0.2 * cos(4*Hprimebar - 63*Pi/180)
	variable SL = 1 + 0.015 * (Lbar-50)^2 / sqrt(20 + (Lbar-50)^2)
	variable SC = 1 + 0.045 * Cprimebar
	variable SH = 1 + 0.015 * Cprimebar * T
	variable RT = -2 * sqrt(Cbar^7/(Cbar^7+25^7)) * sin(Pi/3 * exp(-((Hprimebar-275*Pi/180)/(25*Pi/180))^2))
	return sqrt( (deltaL/SL/kL)^2 + (deltaCprime/SC/kC)^2 + (deltaHprime/SH/kH)^2 + RT * deltaCprime/SC/kC * deltaHprime/SH/kH )
end

static function /WAVE getImageRef()
	string ImageNameString = StringFromList (0, ImageNameList("TracerGraph", ";" ))
	wave/Z w_img = ImageNameToWaveRef("TracerGraph",ImageNameString)
	return w_img
end

static function ShowScaleCursors(int start)
	// make sure we don't already have cursors C-F on graph
	SetWindow TracerGraph hook(setscaleGUI)=$""
	KillControl/W=TracerGraph svC; KillControl/W=TracerGraph svD
	KillControl/W=TracerGraph svE; KillControl/W=TracerGraph svF
	Cursor/K/W=TracerGraph C; Cursor/K/W=TracerGraph D
	Cursor/K/W=TracerGraph E; Cursor/K/W=TracerGraph F
	ControlInfo/W=TracerPanel btnStopScale_g1
	if(v_flag == 1)
		Button btnStopScale_g1, win=TracerPanel, title="Show", Rename=btnStartScale_g1
	endif
	if (start == 0)
		return 0
	endif
	
	string strImage = StringFromList(0, ImageNameList("TracerGraph", ";"))
	wave wImage = ImageNameToWaveRef("TracerGraph", strImage)
	if (WaveExists(wImage) == 0)
		return 0
	endif
	
	variable hSize=DimSize(wImage, 0), vSize=DimSize(wImage,1)
	// vertical hairs for X cursors
	Cursor/N=1/S=2/I/H=2/C=(0,0,65535)/P/W=TracerGraph C $strImage 0.1*hSize, 0.8*vSize
	Cursor/N=1/S=2/I/H=2/C=(0,0,65535)/P/W=TracerGraph D $strImage 0.9*hSize, 0.8*vSize
	// horizontal hairs for Y cursors
	Cursor/N=1/S=2/I/H=3/C=(0,65535,0)/P/W=TracerGraph E $strImage 0.2*hSize, 0.9*vSize
	Cursor/N=1/S=2/I/H=3/C=(0,65535,0)/P/W=TracerGraph F $strImage 0.2*hSize, 0.1*vSize
	
	STRUCT Point pt
	Make/free/T csr={"C","D","E","F"}
	int i
	for(i=0;i<4;i+=1)
		SetVariable $"sv"+csr[i] win=TracerGraph, title="", value=_NUM: i<2 ? hcsr($csr[i]) : vcsr($csr[i])
		SetVariable $"sv"+csr[i] win=TracerGraph, limits={-Inf,Inf,0}, size={40,10}, fsize=14, Proc=Tracer#Rescale
		SetVariable $"sv"+csr[i] win=TracerGraph, valueColor=(0,65535*(i>1),65535*(i<2))
	endfor
	
	SetWindow TracerGraph hook(setscaleGUI)=Tracer#hookSetScale, hookevents=4
	Button btnStartScale_g1, win=TracerPanel, title="Hide", Rename=btnStopScale_g1
	
	// enter hookSetScale function with resize event to reposition setvars
	STRUCT WMWinHookStruct s
	s.WinName = "TracerGraph"
	s.eventcode = 6
	hookSetScale(s)
end

static function hookSetScale(STRUCT WMWinHookStruct &s)
	switch (s.eventcode)
		case 6:
		case 7:
		case 8:
			if (s.eventcode == 7) // cursormoved
				if (GrepString(s.cursorName,"[C-F]") == 0)
					return 0
				endif
				int isX = GrepString(s.cursorName,"[CD]")
					
				// keep axis coordinates within bounds of axes
				variable ptX, ptY
				GetAxis/Q/W=$s.WinName bottom
				ptX = limit(hcsr($s.cursorName, s.winName), min(V_Min,V_Max), max(V_Min,V_Max))
				GetAxis/Q/W=$s.WinName left
				ptY = limit(vcsr($s.cursorName, s.winName), min(V_Min,V_Max), max(V_Min,V_Max))
			
				STRUCT Point pt
				pt.h = PosFromAxisVal(s.WinName, "bottom", ptX)
				pt.v = PosFromAxisVal(s.WinName, "left", ptY)
				
				variable val = isX ? hcsr($s.cursorName,s.WinName) : vcsr($s.cursorName,s.WinName)
				SetVariable $"sv"+s.cursorName win=$s.WinName, value=_NUM:val, pos={pt.h-20,pt.v-10}, disable=0
				break
			endif
	
			// reposition or disable setvars when window is resized
			s.eventCode = 7 // prepare to reenter this function with cursormoved eventcode
			Make/free/T csr={"C","D","E","F"}
			int i
			for(i=0;i<4;i+=1)
				s.cursorName = csr[i]
				variable csrpos = i > 1 ? vcsr($s.cursorName, s.WinName) : hcsr($s.cursorName, s.WinName)
				GetAxis/Q/W=$s.WinName $SelectString(i>1, "bottom", "left")
				if (csrpos>min(v_max,v_min) && csrpos<max(v_max,v_min))
					hookSetScale(s)
				else
					SetVariable $"sv"+(s.cursorName) win=$s.WinName, disable=1
				endif
			endfor
	endswitch
	return 0
end

// this is fired by the setscale setvars
static function Rescale(STRUCT WMSetVariableAction &s)
	if (s.eventCode != 8)
		return 0
	endif
	string strImage = StringFromList(0, ImageNameList(s.win, ";"))
	wave wImage = ImageNameToWaveRef(s.win, strImage)
	int isX = GrepString((s.ctrlName), "[CD]"), autoscale = 1
	ControlInfo/W=TracerPanel $SelectString(isX, "chkLogY_g1", "chkLogX_g1")
	int logAxis = v_value
	if (logAxis && s.dval<=0)
		SetVariable $s.ctrlName win=TracerGraph, value=_NUM:1
	endif
	
	string strAxis, info, flags
	info = ImageInfo(s.win, strImage, 0)
	strAxis = StringByKey(SelectString(isX, "YAXIS", "XAXIS"),info)
	flags = StringByKey("SETAXISFLAGS", AxisInfo(s.win, strAxis))
	variable indexMin, indexMax
	if (GrepString(flags, "/")==0)
		GetAxis/Q $strAxis
		indexMin = scaleToIndex(wImage, V_min, 1-isX)
		indexMax = scaleToIndex(wImage, V_max, 1-isX)
		autoscale = 0
	endif
	
	variable ValCE, ValDF, delta, offset, oldDelta
	ControlInfo/W=$s.win $SelectString(isX, "svE", "svC")
	ValCE = V_Value
	ControlInfo/W=$s.win $SelectString(isX, "svF", "svD")
	ValDF = V_Value
		
	if(logAxis)
		DFREF dfr = root:Packages:Tracer
		wave w = dfr:$SelectString(isX, "TracerLogY", "TracerLogX")
		variable p1 = isX ? pcsr(C) : qcsr(E)
		variable p2 = isX ? pcsr(D) : qcsr(F)
		string strNote=note(wImage)
		w = alog(log(ValCE) + (p-0.5-p1)*(log(ValDF) - log(ValCE))/(p2-p1))
		variable low = alog(log(ValCE) + (-1-p1)*(log(ValDF) - log(ValCE))/(p2-p1))
		variable high = alog(log(ValCE) + (DimSize(w,0)-1-p1)/(p2-p1)*(log(ValDF) - log(ValCE)))
		strNote = ReplaceNumberByKey(SelectString(isX,"YHIGH","XHIGH"), strNote, low)
		strNote = ReplaceNumberByKey(SelectString(isX,"YLOW","XLOW"), strNote, high)
		note/K wImage, strNote
		
		if (autoscale)
			if (w[1] > w[0])
				if (isX)
					SetAxis/A/W=TracerGraph bottom
				else
					SetAxis/A/R/W=TracerGraph left
				endif
			else
				if (isX)
					SetAxis/A/R/W=TracerGraph bottom
				else
					SetAxis/A/W=TracerGraph left
				endif
			endif
		endif
		return 0
	endif
			
	delta = isX ? (ValDF-ValCE)/(pcsr(D)-pcsr(C)) : (ValDF-ValCE)/(qcsr(F)-qcsr(E))
	offset = isX ? ValCE - delta*pcsr(C) : ValCE - delta*qcsr(E)
	oldDelta = DimDelta(wImage, 1-isX)
	if (isX)
		SetScale/P x, offset, delta, wImage
	else
		SetScale/P y, offset, delta, wImage
	endif
	if (autoscale == 0)
		// don't use IndexToScale, because ends of axis may fall outside of image
		v_min = DimOffset(wImage, 1-isX) + indexMin*DimDelta(wImage, 1-isX)
		v_max = DimOffset(wImage, 1-isX) + indexMax*DimDelta(wImage, 1-isX)
				
		if (v_min > v_max)
			SetAxis/R/W=$s.win $strAxis v_min, v_max
		else
			SetAxis/W=$s.win $strAxis v_min, v_max
		endif
	elseif ((sign(oldDelta)==sign(delta)) %^ GrepString(flags, "/R"))
		// switch the axis limits so that image is not flipped
		SetAxis/A/W=$s.win $strAxis
	else
		SetAxis/A/R/W=$s.win $strAxis
	endif

	return 0
end

// copy and paste image scale
menu "TracePopup", dynamic
	tracer#ScaleMenuString(0), /Q, tracer#CopyImageScale()
	tracer#ScaleMenuString(1), /Q, tracer#PasteImageScale()
end

static function /S ScaleMenuString(int paste)
	if (WinType("") != 1)
		return "" // don't do anything if Igor is just rebuilding the menu
	endif
	// figure out graph and trace names
	GetLastUserMenuInfo
	if(strlen(ImageNameList(s_graphname, ";")) == 0)
		return ""
	endif
	if (paste == 0)
		return "Copy Image Scale"
	elseif (cmpstr(GetScrapText()[0,7], "SetScale")==0)
		return "Paste Image Scale"
	endif
	return ""
end

static function CopyImageScale()
	GetLastUserMenuInfo
	wave/Z w = ImageNameToWaveRef(s_graphname, StringFromList(0, ImageNameList(s_graphname, ";")))
	if (WaveExists(w) == 0)
		return 0
	endif
	string cmd = ""
	sprintf cmd, "SetScale/P x, %g, %g, ###; SetScale/P y, %g, %g, ###;", DimOffset(w, 0), DimDelta(w, 0), DimOffset(w, 1), DimDelta(w, 1)
	PutScrapText cmd
end

static function PasteImageScale()
	GetLastUserMenuInfo
	string strImage = StringFromList(0, ImageNameList(s_graphname, ";"))
	wave/Z wImage = ImageNameToWaveRef(s_graphname, strImage)
	if (WaveExists(wImage) == 0)
		return 0
	endif
	
	variable x0, dx, y0, dy
	sscanf GetScrapText(), "SetScale/P x, %g, %g, ###; SetScale/P y, %g, %g, ###;", x0, dx, y0, dy
	if (V_flag != 4)
		return 0
	endif
	
	int autoscale, dim
	string strAxis = "", info = "", flags = ""
	info = ImageInfo("", strImage, 0)
	variable indexMin, indexMax, delta, oldDelta
	
	for (dim=0;dim<2;dim+=1)
		autoscale = 1
		straxis = StringByKey(SelectString(dim, "XAXIS", "YAXIS"), info)
		flags = StringByKey("SETAXISFLAGS", AxisInfo("", strAxis))
		
		oldDelta = DimDelta(wImage, dim)
		delta = dim ? dY : dX
		
		if (GrepString(flags, "/")==0)
			GetAxis/Q $strAxis
			indexMin = scaleToIndex(wImage, V_min, dim)
			indexMax = scaleToIndex(wImage, V_max, dim)
			autoscale = 0
		endif
		if (dim == 0)
			SetScale/P x, x0, delta , wImage
		else
			SetScale/P y, y0, delta , wImage
		endif
		if (autoscale == 0)
			
			// don't use IndexToScale, because ends of axis may fall outside of image
			v_min = DimOffset(wImage, dim) + indexMin*DimDelta(wImage, dim)
			v_max = DimOffset(wImage, dim) + indexMax*DimDelta(wImage, dim)
			
			if (v_min > v_max)
				SetAxis/R $strAxis v_min, v_max
			else
				SetAxis $strAxis v_min, v_max
			endif
		endif
		if (sign(oldDelta) != sign(delta))
			// switch the axis limits so that image is not flipped
			if (GrepString(flags, "/R"))
				SetAxis/A $strAxis
			elseif (GrepString(flags, "/A"))
				SetAxis/A/R $strAxis
			endif
		endif
	endfor
end

// for a graph window, when resolution is 96 or lower on Windows we use points.
static function PosFromAxisVal(string graphNameStr, string axNameStr, variable val)
	variable pixel = PixelFromAxisVal(graphNameStr, axNameStr, val)
	variable resolution = ScreenResolution
	return resolution > 96 ? pixel * 72/resolution : pixel
end

static function /wave CirclePointWave(int xm, int ym, int r)

	int x = -r, y = 0, err = 2-2*r // 2nd Quadrant
	Make/O/n=(0,4) wx, wy // columns for quadrants 1-4
	do
		wx[DimSize(wx,0)][] = {{xm-x},{xm-y},{xm+x},{xm+y}}
		wy[DimSize(wy,0)][] = {{ym+y},{ym-x},{ym-y},{ym+x}}
		r = err
		if (r <= y)
			err += ++y * 2 + 1 // e_xy+e_y < 0
		endif
		if (r > x || err > y)
			err += ++x * 2 + 1 // e_xy+e_x > 0 or no 2nd y-step
		endif
	while (x < 0)

	Redimension/N=(4*DimSize(wx,0)) wx, wy
	Concatenate/free {wx, wy}, w
	return w
end

static function /wave LinePointWave(int x0, int y0, int x1, int y1)

	int dx =  abs(x1-x0), sx = x0<x1 ? 1 : -1
	int dy = -abs(y1-y0), sy = y0<y1 ? 1 : -1
	int err = dx+dy, e2 // error value e_xy */

	Make/free/N=(0,2) w
	do
		w[DimSize(w,0)][] = {{x0}, {y0}}
		//     	setPixel(x0,y0);
		if (x0==x1 && y0==y1)
			break
		endif
		e2 = 2*err
		if (e2 >= dy)
			err += dy
			x0 += sx //e_xy+e_x > 0 */
		endif
		if (e2 <= dx)
			err += dx
			y0 += sy // e_xy+e_y < 0 */
		endif
	while (1)
	return w
end

static function MakeCirclePointWave(int xm, int ym, int r)

	int x = -r, y = 0, err = 2-2*r // 2nd Quadrant
	Make/O/n=(0,4) wx, wy // columns for quadrants 1-4
	do
		wx[DimSize(wx,0)][] = {{xm-x},{xm-y},{xm+x},{xm+y}}
		wy[DimSize(wy,0)][] = {{ym+y},{ym-x},{ym-y},{ym+x}}
		r = err
		if (r <= y)
			err += ++y * 2 + 1 // e_xy+e_y < 0
		endif
		if (r > x || err > y)
			err += ++x * 2 + 1 // e_xy+e_x > 0 or no 2nd y-step
		endif
	while (x < 0)

	Redimension/N=(4*DimSize(wx,0)) wx, wy
	Concatenate/free {wx, wy}, w
	Duplicate/O w circle
end

// *** Bezier to wave functions ***

static function CL_SetUpDrawingMode()
	if (strlen(ImageNameList("TracerGraph", ";" )) == 0)
		DoAlert 0, "No image display!"
		return 0
	endif
	
	ShowTools/A/W=TracerGraph arrow
	SetDrawLayer/W=TracerGraph UserFront
	SetDrawEnv/W=TracerGraph linefgc=(65535,0,0), fillpat=0, linethick=2.00, xcoord=bottom, ycoord=left
	DoAlert 0, "Click on the polygon drawing tool, then select \"Draw Bezier\".\rClick 'Extract Bezier' to finish."
end

static function CL_ClearUserFront()
	SetDrawLayer/W=TracerGraph/K UserFront
	HideTools/A/W=TracerGraph
	GraphNormal/W=TracerGraph
end

static function CL_ExtractBezier()
	
	// go back to graph normal
	GraphNormal/W=TracerGraph
	HideTools/A/W=TracerGraph
	
	// get control parameters
	STRUCT PanelStatusStructure s
	FillPanelStructure(s)
	 	
	if (CheckName(s.tracename.sval, 1))
		DoAlert 1, s.tracename.sval + " already exists. Overwrite?"
		if (V_Flag == 2)
			return 0
		endif
	endif
	
	variable xorg, yorg, hscaling, vscaling, isAbsolute
   string coordinates = CL_GetBezierCoordinates("TracerGraph", xorg, yorg, hscaling, vscaling, isAbsolute)
   
   if ( ItemsInList(coordinates, ",") < 5 )
		DoAlert 0, "Can't find a bezier curve!"
		return 0
	endif
   	
	variable numItems = ItemsInList(coordinates,",")
	variable n = numItems/2
	Make/O/D/N=(n)/FREE wx = str2num(StringFromList(0+p*2,coordinates,","))
	Make/O/D/N=(n)/FREE wy = str2num(StringFromList(1+p*2,coordinates,","))
	
	#if IgorVersion() >= 9
	BezierToPolygon/NSEG=(s.segpnt.value) wx,wy
	#else
	DoAlert 0, "Bezier tracing requires Igor Pro 9+"
	return 0
	#endif
	
	wave W_PolyX, W_PolyY
	
	if (!s.XY.value)
		Make/free w_diff
		Differentiate W_PolyX /D=w_diff
		WaveStats/Q/M=0 w_diff
		if (V_max>0 && V_min<0)
			DoAlert 0, "Curve is not monotonic in X, output will be XY data!"
			s.XY.value = 1
		endif
	endif
	
	if (s.XY.value)
		Duplicate/O W_PolyX, $s.tracename.sval + "_X"
		Duplicate/O W_PolyY, $s.tracename.sval
	else
		Make/O $s.tracename.sval
		Wave W_Bezier = $s.tracename.sval
		Interpolate2/T=1/N=(numpnts(W_PolyY))/Y=W_Bezier W_PolyX, W_PolyY
		// maybe better to use /N=max(number of rows of image traversed, number of points in bezier)
	endif
	
	// is trace already on graph?
	if (FindListItem(s.tracename.sval, TraceNameList("TracerGraph", ";", 1)) == -1)
		if (s.XY.value)
			AppendToGraph/W=TracerGraph $s.tracename.sval vs $s.tracename.sval + "_X"
		else
			AppendToGraph/W=TracerGraph $s.tracename.sval
		endif
		ModifyGraph/W=TracerGraph lsize=3, rgb=(44253,29492,58982)
	endif
	KillWaves/Z W_PolyX, W_PolyY
	
	CL_ClearUserFront()
		
	return 1
end

static function/S CL_GetBezierCoordinates(string win, variable &xorg, variable &yorg, variable &hscaling, variable &vscaling, variable &isAbsolute)
	// code by Jim Prouty; https://www.wavemetrics.com/forum/general/convert-bezier-xy-wave
    string list = WinRecreation(win,4) // lines end with \r
    // look for first DrawBezier or DrawBezier/ABS command,
    // and accumulate coordinates from immediately following DrawBezier/A commands.
    // Stop accumulating when the next command is NOT DrawBezier/A.
    string separator = "\r"
    variable separatorLen = strlen(separator)
    variable numItems = ItemsInList(list, separator)
    variable i, offset = 0
    variable foundBezier = 0
    string bezierkey="\tDrawBezier "
    string absbezierkey="\tDrawBezier/ABS "
    string appendKey="\tDrawBezier/A "
    string coordinates=""
    for(i=0; i<numItems; i+=1)
        string item = StringFromList(0, list, separator, offset) // When using offset, the index parameter is always 0
        variable isDrawBezier = cmpstr(bezierkey,    item[0,strlen(bezierkey)-1]) == 0
        variable isAbsbezier  = cmpstr(absbezierkey, item[0,strlen(absbezierkey)-1]) == 0
        variable isAppend     = cmpstr(appendKey,    item[0,strlen(appendKey)-1]) == 0

        if ( !foundBezier && (isDrawBezier || isAbsbezier) )
            // we have "\tDrawBezier 42,85,1,1,{42,85,...}"
            // or "\tDrawBezier/ABS 0,0,1,1,{48,104,...}"
            isAbsolute = isAbsbezier
            variable prefixLen = isAbsbezier ? strlen(absbezierkey) : strlen(bezierkey)
            sscanf item[prefixLen,strlen(item)-1], "%g,%g,%g,%g,{", xorg, yorg, hscaling, vscaling
            SplitString/E=".*\{(.*)\}" item, coordinates
    
            foundBezier = 1
        elseif ( foundBezier )
            if ( !isAppend ) // must be a command AFTER DrawBezier and optional DrawBezier/A
                break       // this prevents appending coordinates from additional bezier objects.
            endif
            // we have "\tDrawBezier/A {48,104,48,104}"
            string more
            SplitString/E=".*\{(.*)\}" item, more
            coordinates += ","+more
            // keep going, multiple DrawBezier/A commands are allowed.
        endif
        offset += strlen(item) + separatorLen
    endfor
    return coordinates
end

// PNG: width= 90, height= 30
static Picture pHelp
	ASCII85Begin
	M,6r;%14!\!!!!.8Ou6I!!!"&!!!!?#R18/!3BT8GQ7^D&TgHDFAm*iFE_/6AH5;7DfQssEc39jTBQ
	=U%&ule5u_NK]pa@g']g@U^Upt%GFQ2iG6aJpJmdFX78;,cVIC:7E<8Td:b6cN,?9UjVf\f%WZ;[/V
	%KP#JO*M&WN?THKK9cU)`=`H0[O9,)L8;-_'G*Bak\80]?@nUmHm(8j1N'qpQ@[GqTSkLm[iV;4l?5
	9p34hHca--pCc9?`a1`N@?0>MW\`C_cK87>p!!)X0(AW7k(<k1!Z6U5Zb%=PW#*`9'?8(R.l9\9B%n
	9#Xi,CY"\p?O1oCK4p_#dS:<['Ueqmu'!DdI1i5jrP3+p\-^L%B)Rl&&6R@eFq>=L[qbCBEtmmNr/L
	*e`#,Pc(S2@J/p9W2QZ)-J]W[Rki??laDuDX[@&P,(^^j"-[%#SONo\V1=G'!!%70KV'(>nd;T\r9s
	nW!!']u`J45Y;-RJO#^h#IS8@)s?-6E37K\jr"J&9mNoQd1W?So9&&7!4QcfPj`<*6p)q!4%Z!kNSb
	ab*S0C)+!-4P&qo6Jd<2$QkkZlF^m=^($s8m)tsn,tIZn\F/q!JI,[b(u%<c'JV4aX<^Bf%*k%J6&^
	>;,IqtHG)FHLBE0]KCF+J!.aqBH9Cu\K<fV!+1qo2IdrI^jN)fkTP5;J-4NXp%T0D`+g<s/YW;Xf"@
	\,T!Yqbd?E6KnN%F4r'*)'g*uD%cKYq4thknG`:Fo$Eh;$dZNZ:%ld4Hbsa^bHA79m^g0PiWdCc346
	JH/)8KM&)(k36QF'1-*7>&j)l`JADS2'.,2Z*_)fH$KMmMP'\-](',%?j1@)>F]S9TO0p.T!W[#6cg
	fTP-7;t(+Zf_JqtSn,aMH!n\';3U2ZD&S;P.=h1rnGXk<CB$fKN,kd+9PO4u%TJ&Hu4&4Crs9Y@_nH
	"MR&l)1>b[1u<1&g\hMaNi(kl1-rkL5)pKfeO6U'VM\7&0/`!A7PfqQOE]am/tCKELH9=]@#NnO'jY
	tqYGLh>IH)^mct,(P9&uXOhUj'bDC#sD;2^*qE?dh;P68RpF'`l^&V357%l%naPeh(A($.glRQtugt
	ZGl%$*W+%Ia6#,81..8g^]id,Kck$t@][$aBOjq/OasMhNuG2M,LC'G_J("Z[P4_r5QBmFntXjd',6
	lZt\G^OJI;7Rj%OX5iIM#6uCX!]FoLK`(amh5S'MpXVq/O#EQ=C>KI[/s=orf,T\.V5"J]r\=n:<P^
	dbK.Jkf0au0o*Zjc5<u!+J$%sur)3hjN3<hR:W<>kX3+#G"^cXsdL/hY`gSKQ2hQ^Pq(l!UpCdqH+(
	.;#abis6/fk6q:$aRh5_>*eM9NS:6RPelrZ>?$aa)Nf&c!V@m]6<R6e=FIgEcWdq5MWd4Wd(EGH-(t
	7'6n3kpg)VSEUsmM3$iUNPR)sTB+NfY$cV71VX=4n!'f7b&o2]5j7tq;=*jFX8d1ff/P>NYa\kIC.H
	0D<]`$GJ&fmmVZ]hoTDId<i+X\WBThm/_*d[#n'GhQY]#TjRa0oj>Y^?+^*&qn&>%qpqLF8^A1;Q1&
	-O1QL#&^mh-Vg1nFHc5Yg_^Fm5Mj%+,Mn_\Yol9dGTnRi%0.uNj'\-e(in+;$'enZ/=ITkLsojIs'f
	5J4*Sf)rJ-0)p,hFVP)c6^;1hlKdF&nZ-FC.eJ7Vk#%#29.N7pubh'DZ93h9r&DjT2'SNDUuSfXk:T
	hm!T6a,*oAQcCI[)@&bnCG;H\^W#'+J+VfO[ZNjXF'@+Pe?YI;kq8O!7WJ6/>GbW`_[MnT91E/eol'
	bTm^=u,IJJ5lD.poMum`/$SP;Lj,6doEk."\m=nfH#0X:Yfbb'MOIr-edqrknBHJ'.M!5h;8]P4A(2
	C5q?EY.TLP&:@>Ph$?Yg`,3D[$dC9?0\Lot/&E.W?j`_I5L)S`l("cMF\gETWuSY0H>CU9[07$'*X?
	.ECCH8hd=RSR5*cX/cU:_gpc,KYucE`q+RG\$$<TcCB`,F1^8,XK7BFNf9bRLZ:?J%"ljN:<;Dmlr<
	<hnCr)p-KUd:j9K#ZR[0<)\a0F9.RDN?6IID#?^a.u`5-q,0f8$Rlf7RA:d.C+<VOe$lIo%e;iX5o1
	`08MhTJ)r/NmJY-DDFd-.d!K_Rt0c0JkU#f>m(GTtJ#XKnY4Yh:U@^b&M*`#/`.YmHm=QB$'%\qX#r
	@k9m_?!'^:&'rj398\D*jgar,Hmr+Pss6/[R]X5WiKS!V5MLl\*=I@$r(oGZ,`<UmS89I+G&ERttG\
	?uGTYJ4QI94'p5&O$_NuCGa:bXG:/cc`G"U[\/_&o4D^R9qQ.&+2[(Oj,+Wf%(,h7@a%l,]TuYHJJ]
	c-7[nR\D2Y'FNK/2Is\:pn`I55s*LoL%75rm!\:SWNQ!$7lE$\oEiU0_1I2l(qmg9mW>fI686_Rj.5
	jeJn6.1(2"3)s(MJI+9@R=1DURoE!UFZS]K(#"X+#C.&IfNW]P,?eu`-]QAr!;/J\^(*&mqjc^33aT
	ho-+@KOjAb]rUUj[oC9NQ;ek29;O&*`'Q"/";k+Tg7'`6o+_GJCHppi2q`P`s):,hk.sAA13FNUdVO
	CqH6RTVp:'Y5Q5n4OSA+pK<_\dBuc<WYCcMO?Q@,LgL<7c;$W^J0;HuM+9W5^S^q4aWOpsd@r>fnk2
	So.FRL?T3's"<s%-?!6l<9^F=LQcfaIk'F`fAVN=fHg&+@:55-A/$,0Q;a!e\;h*Lf(XaXKL[!4-!c
	aqqcW-G6]?LB/PBBUY6(jb9r[dt)"0%,6E?I7ZC,@h&U9d0N'0B"I*cP&=W6+,5Q+jm*N\UX=lkGu&
	=k,OT/8_;BQ/7_Ej-C_!.H&/7RV2C0;(69I-DBB1!=ngL'RTsV0@Thl"/7EIHaEf0:a;]5Cc66VSZQ
	6I"!Xu@+C"F9t&6)h$QNJ4Z`l)J2%pja/;XcRC:V`\qo7%>:kj303LOY7gGU9[=BWi@Q<4J,J?\$`W
	[j`9>Hfs<YZk"J7Y4O9e.Z4_2'41CGG!H$J1+c^co`cG$^kE[l+]TgZQ_ZQAl-Ye&1(foL%GJNZubA
	I=\jNa+r25c`$-\_d!-SF>`c$*"bnA5Pd&@G[NL1-s#NT^QJE4K3ch;$eqe%2otU'SNkO0)Wq;?3TU
	rR^1M8Y>J.e=2WqS,EtAVsr+7Ye3:5n)T/gm&69l`j'CTj4Lg;;));SI-5M&;0PNH(V+qhEd59(q77
	:UfXZ&NG4+.BMM_c:\fMCIl=*8Wl$0*1n"*V,VrbVTeamc>-QOiL!'a[j8ho<N"<e&.<_R:uIoHWYJ
	V2XkU$7DS=[%EK"=$\$kMQ0&ZlWD`GVR/k$j8kX2:&F1\IrM\).p2mX&c?cjWb$4(kt>!Fg\$7MYDA
	UHms%/2@dgf]sf_>hK$8KIS*p\IF@UM*pf19J:qKEM*`+C1)HeU%mj[5%,n0(A&?QmTqML1]D_'#VU
	*PTY.VJl],a[1oi.[R2gCCs)EWsbZM?gV]Lt.iOP5c/>+CgY](/@X'N)9IE>TW8![nBi9rGA-g7>Hp
	7+aXH[X[R9gD:QXZ-eK.]oBqplJdKII8NiR<EiZXD*$*VkL$%p@CP!"\(botnDUa&J]RXWD/Cjs8kK
	_<Vt(nb'K\+MDAp)9hWgu3=Kl-_8`3<f3W%U'e"ljrNP(a<ThrgW8>ReE0a-h(!L0!@m!e[%Zs0JWq
	t?0?mV_+Ij[j)-=03DO_eQTRXK2hGf<1D3EY\ZChfAPHFN"fO]NbF:l!M_*b:=[),oo-29QT>^V:Jn
	:-m.rqHKcs0/5Y;,CW^2$p-3Z_&F&EBJB;>bhJ?i+bO_rAXf/4u_28sXAEi7<jcOgQrqM6=VYgP@_8
	H64h2ZJOlBs?ebm(55\!.MW!DM.KJ-<m>:brccmn<T3VCVWDrT)dYhZZGG0Gk5H\]2"fJq/]7#nTGM
	d*Rkr\k#n?2".f$$2_u>^Ei3E4V/;GBQFSYB4Z]qWhhRd8-hNf"q^:7iL-29.seIBTbbt(s41u^CK<
	qq#AJ*pLEHlLC:2KZR-9u#'FI,;"9\c,GW[%O/;p>tQ_L@Sk*gC1'^rD[Ng<&QqT8!\!;\90X=aNKD
	r`TCVbt6obG&O5$4H$sZ/XWa124<T4?Q;4T0A86rdItO<p@AD3h6a-P6iN]-!7Zr+m.(@HX1ct2t-b
	HR`A77"JcKsz8OZBBY!QNJ
	ASCII85End
end

// returns truth that this procedure file has been updated since initialisation
static function CheckUpdated(string win, int restart)	
	if (cmpstr(GetUserData(win, "", "version"), num2str(ProcedureVersion(""))))
		if (restart)
			DoAlert 0, "You have updated the package since this panel was created.\r\rThe package will restart to update the control panel."
			Initialise()
		else
			DoAlert 0, "You have updated the package since this panel was created.\r\rPlease close and reopen the panel to continue."
		endif
		return 1
	endif
	return 0
end

// note that neither built-in ProcedureVersion("") nor this function work
// for independent modules!
#if (exists("ProcedureVersion") != 3)
// replicates ProcedureVersion function for older versions of Igor
static function ProcedureVersion(string win)
	variable noversion = 0 // default value when no version is found
	if (strlen(win) == 0)
		string strStack = GetRTStackInfo(3)
		win = StringFromList(ItemsInList(strStack, ",") - 2, strStack, ",")
		string IM = " [" + GetIndependentModuleName() + "]"
	endif
	
	wave/T ProcText = ListToTextWave(ProcedureText("", 0, win + IM), "\r")	
	
	variable version
	Grep/Q/E="(?i)^#pragma[\s]*version[\s]*=" /LIST/Z ProcText
	s_value = LowerStr(TrimString(s_value, 1))
	sscanf s_value, "#pragma version = %f", version

	if (V_flag!=1 || version<=0)
		return noversion
	endif
	return version	
end
#endif