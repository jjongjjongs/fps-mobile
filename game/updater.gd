extends Node

signal changed
enum Stage { IDLE, CHECKING, CURRENT, AVAILABLE, DOWNLOADING, READY, FAILED }
const API := "https://api.github.com/repos/jjongjjongs/fps-mobile/releases/latest"
const RELEASES := "https://github.com/jjongjjongs/fps-mobile/releases/download/"
const FOLDER := "user://updates"
const PART := FOLDER+"/download.part"
const LIMIT := 200*1024*1024
var stage := Stage.IDLE
var message := ""
var target := ""
var asset_url := ""
var digest := ""
var size_bytes := 0
var metadata := HTTPRequest.new()
var transfer := HTTPRequest.new()

func _ready():
	add_child(metadata)
	add_child(transfer)
	metadata.use_threads=true
	transfer.use_threads=true
	transfer.download_chunk_size=262144
	metadata.timeout=18
	metadata.body_size_limit=1024*1024
	transfer.timeout=240
	transfer.body_size_limit=LIMIT
	transfer.download_file=PART
	metadata.request_completed.connect(on_metadata)
	transfer.request_completed.connect(on_transfer)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FOLDER))
	clear_old_files()

func clear_old_files(keep: String=""):
	for item in DirAccess.get_files_at(FOLDER):
		if item!=keep and (item=="download.part" or (item.begins_with("vector-") and item.ends_with(".apk"))):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(FOLDER.path_join(item)))

static func code(version: String) -> int:
	var pieces:=version.split(".")
	if pieces.size()!=3: return -1
	var value:=0
	for piece in pieces:
		if piece=="" or not piece.is_valid_int() or str(piece.to_int())!=piece or piece.to_int()<0 or piece.to_int()>999: return -1
		value=value*1000+piece.to_int()
	return value

func set_stage(next: Stage, info: String):
	stage=next
	message=info
	changed.emit()

func check():
	if stage in [Stage.DOWNLOADING,Stage.CHECKING]: return
	set_stage(Stage.CHECKING,"새 버전을 확인하는 중입니다.")
	if metadata.request(API,["Accept: application/vnd.github+json","User-Agent: VectorRange-Android"])!=OK:
		set_stage(Stage.FAILED,"버전 조회를 시작하지 못했습니다.")

func on_metadata(result: int,status: int,_headers: PackedStringArray,body: PackedByteArray):
	if result!=HTTPRequest.RESULT_SUCCESS or status!=200:
		set_stage(Stage.FAILED,"릴리스에 연결하지 못했습니다. 잠시 후 다시 확인하세요.")
		return
	var release=JSON.parse_string(body.get_string_from_utf8())
	if not release is Dictionary or release.get("draft",true) or release.get("prerelease",true):
		set_stage(Stage.FAILED,"정식 릴리스 정보를 확인할 수 없습니다.")
		return
	target=str(release.get("tag_name","")).trim_prefix("v")
	if code(target)<0:
		set_stage(Stage.FAILED,"릴리스 버전을 읽을 수 없습니다.")
		return
	if code(target)<=code(ProjectSettings.get_setting("application/config/version")):
		set_stage(Stage.CURRENT,"최신 버전을 사용 중입니다.")
		return
	var filename:="VectorRange-%s-release-arm64.apk"%target
	asset_url=RELEASES+"v"+target+"/"+filename
	for entry in release.get("assets",[]):
		if entry.get("browser_download_url","")!=asset_url or entry.get("name","")!=filename: continue
		digest=str(entry.get("digest","")).trim_prefix("sha256:").to_lower()
		size_bytes=int(entry.get("size",0))
		if digest.length()!=64 or not digest.is_valid_hex_number() or size_bytes<=0 or size_bytes>LIMIT: continue
		set_stage(Stage.AVAILABLE,"새 버전 %s · %.1f MB"%[target,size_bytes/1048576.0])
		return
	set_stage(Stage.FAILED,"확인할 수 있는 정식 설치 파일이 없습니다.")

func download():
	if stage!=Stage.AVAILABLE: return
	clear_old_files()
	set_stage(Stage.DOWNLOADING,"설치 파일을 내려받고 있습니다.")
	if transfer.request(asset_url,["User-Agent: VectorRange-Android"])!=OK:
		set_stage(Stage.FAILED,"다운로드를 시작하지 못했습니다.")

func apk() -> String:
	return FOLDER.path_join("vector-"+target+".apk")

func on_transfer(result: int,status: int,_headers: PackedStringArray,_body: PackedByteArray):
	var file:=FileAccess.open(PART,FileAccess.READ)
	var valid:=result==HTTPRequest.RESULT_SUCCESS and status==200 and file!=null and file.get_length()==size_bytes
	file=null
	if not valid or FileAccess.get_sha256(PART)!=digest:
		clear_old_files()
		set_stage(Stage.FAILED,"다운로드가 중단됐거나 파일이 일치하지 않습니다. 다시 확인하세요.")
		return
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(PART),ProjectSettings.globalize_path(apk()))!=OK:
		set_stage(Stage.FAILED,"설치 파일을 저장하지 못했습니다.")
		return
	set_stage(Stage.READY,"다운로드가 완료됐습니다. 설치 창에서 업데이트를 승인하세요.")

func install():
	if stage!=Stage.READY: return
	if OS.get_name()!="Android":
		set_stage(Stage.FAILED,"안드로이드 기기에서 설치할 수 있습니다.")
		return
	if OS.shell_open(ProjectSettings.globalize_path(apk()))!=OK:
		set_stage(Stage.READY,"설치 창을 열 수 없습니다. 다시 시도하세요.")
	else:
		set_stage(Stage.READY,"설치 창에서 승인하세요. 권한을 허용한 뒤에는 다시 누를 수 있습니다.")
