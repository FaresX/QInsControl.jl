# ============================================================================
# 应用内更新(仿 WebDashboard 平铺模式,无独立 module)
#
# 流程:检查 GitHub Releases 的补丁链 → 后台依次下载到安装根目录 → 用户点
# "退出并安装"走正常退出路径 → 启动器链(runapp.cmd → 更新.cmd)一次性应用全部
# 补丁并重启。安装是纯文件覆盖、不跑 Julia;补丁携带的预编译缓存配合构建侧
# 的源码树 mtime 规范化(build_portable.jl),安装后启动零重编译。
#
# 便携形态判定:installroot() 目录下存在 更新.cmd;否则一切操作降级为
# "打开发布页"(非便携安装走浏览器更新)。
#
# 补丁资产命名约定(scripts/portable/make_patch.jl 生成,随 GitHub Release 分发):
#   QInsControl-Patch-v{A}_to_v{B}-<时间戳>.zip
# ============================================================================

const PatchInfo = NamedTuple{
    (:from, :to, :name, :url, :size),
    Tuple{VersionNumber, VersionNumber, String, String, Int}
}

const UPDSTATE = Lockable(Dict{Symbol, Any}(
    :phase => :idle,   # idle/checking/ready/unsupported/downloading/downloaded/failed
    :latest => VersionNumber(0),
    :chain => PatchInfo[],
    :item => 0,        # 正在下载第几个补丁
    :done => 0,        # 当前补丁已收字节
    :total => 0,       # 当前补丁总字节
    :reason => "",     # ready 且链为空时的说明(已最新/断链需整包)
    :err => "",        # 失败原因
))

"便携安装根目录(存在 update.cmd 即判定);非便携形态返回 nothing"
function installroot()
    assets = haskey(ENV, "QInsControlAssets") ? ENV["QInsControlAssets"] :
        normpath(joinpath(@__DIR__, "..", "..", "Assets"))
    root = dirname(assets)
    return isfile(joinpath(root, "update.cmd")) ? root : nothing
end

"从 GitHub Releases 解析从当前版本到最新版本的补丁链,结果写 UPDSTATE(后台执行)"
function checkupdate!()
    phase = lock(st -> st[:phase], UPDSTATE)
    (phase == :checking || phase == :downloading) && return
    isnothing(installroot()) && return lock(st -> st[:phase] = :unsupported, UPDSTATE)
    lock(st -> begin
        st[:phase] = :checking
        st[:reason] = ""
        st[:err] = ""
    end, UPDSTATE)
    dorender()
    @spawn_record "update: check" begin
        for i in 1:6
            try
                rels = releases("FaresX/QInsControl.jl"; per_page = 100)[1]
                tags = VersionNumber[]
                patches = Dict{VersionNumber, PatchInfo}()
                for rel in rels
                    rel.tag_name === nothing && continue
                    v = try
                        VersionNumber(rel.tag_name)
                    catch
                        continue
                    end
                    push!(tags, v)
                    rel.assets === nothing && continue
                    for a in rel.assets
                        m = match(r"^QInsControl-Patch-v(\d[\d.]*)_to_v(\d[\d.]*)", get(a, "name", ""))
                        m === nothing && continue
                        from = VersionNumber(m.captures[1])
                        to = VersionNumber(m.captures[2])
                        patches[from] = (
                            from = from,
                            to = to,
                            name = a["name"],
                            url = string(a["browser_download_url"]),
                            size = Int(get(a, "size", 0)),
                        )
                    end
                end
                cur = FILEINFO["QInsControl version"]
                latest = isempty(tags) ? cur : max(tags...)
                # 沿 _to_ 链从当前版本走到最新;中途断链则停(只拿到能连上的前缀)
                chain = PatchInfo[]
                v = cur
                while v < latest
                    p = get(patches, v, nothing)
                    p === nothing && break
                    push!(chain, p)
                    v = p.to
                end
                reason = ""
                if latest <= cur
                    reason = mlstr("already the latest version!")
                elseif isempty(chain)
                    reason = mlstr("no patch chain from this version, please download the full package from the release page")
                end
                STATES[NewVersion] = latest > cur
                lock(st -> begin
                    st[:latest] = latest
                    st[:chain] = chain
                    st[:reason] = reason
                    st[:phase] = :ready
                    st[:err] = ""
                end, UPDSTATE)
                break
            catch e
                i == 6 && begin
                    @warn "[$(now())]\nfailed to check new version" exception = e
                    lock(st -> begin
                        st[:phase] = :failed
                        st[:err] = sprint(showerror, e)
                    end, UPDSTATE)
                end
                sleep(1)
            finally
                dorender()
            end
        end
    end
    return nothing
end

"依次下载 UPDSTATE 里的补丁链到安装根目录(后台执行;完成后由启动器链在退出后安装)"
function startdownload!()
    root = installroot()
    ph, nchain = lock(st -> (st[:phase], length(st[:chain])), UPDSTATE)
    (isnothing(root) || ph != :ready || nchain == 0) && return
    lock(st -> begin
        st[:phase] = :downloading
        st[:err] = ""
    end, UPDSTATE)
    dorender()
    @spawn_record "update: download" begin
        try
            n = lock(st -> length(st[:chain]), UPDSTATE)
            for i in 1:n
                nt = lock(st -> st[:chain][i], UPDSTATE)
                lock(st -> begin
                    st[:item] = i
                    st[:done] = 0
                    st[:total] = nt.size
                end, UPDSTATE)
                dorender()
                dest = joinpath(root, nt.name)
                part = dest * ".part"
                isfile(part) && rm(part; force = true)
                Downloads.download(nt.url, part; progress = (total, now) -> begin
                    # total==0(分块传输无长度)时保留资产元数据里的标称大小
                    lock(st -> begin
                        st[:done] = now
                        total == 0 || (st[:total] = total)
                    end, UPDSTATE)
                    dorender()
                end)
                mv(part, dest; force = true)
            end
            lock(st -> st[:phase] = :downloaded, UPDSTATE)
            toast(:success, mlstr("updates downloaded!"), mlstr("they will be installed automatically after exit"))
        catch e
            @warn "[$(now())]\nfailed to download updates" exception = e
            lock(st -> begin
                st[:phase] = :failed
                st[:err] = sprint(showerror, e)
            end, UPDSTATE)
            toast(:error, mlstr("failed to download updates"), sprint(showerror, e))
        finally
            dorender()
        end
    end
    return nothing
end
