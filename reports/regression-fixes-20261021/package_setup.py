"""Package source fixes and independent setup tools, never private data."""
from pathlib import Path
import json
import subprocess
import tempfile
from zipfile import ZipFile, ZIP_DEFLATED

ROOT=Path(__file__).resolve().parents[2]
OUTPUT=ROOT/'dist/Independent-Test-Setup-20261022-v4.zip'

def git(*args):
    return subprocess.check_output(['git',*args],cwd=ROOT)

def main():
    if OUTPUT.exists():raise FileExistsError('Preserve existing bundle: '+str(OUTPUT))
    paths=['scripts','tests','tools']
    patch=git('diff','--binary','HEAD','--',*paths)
    changed=git('diff','--name-only','HEAD','--',*paths).decode().splitlines()
    added=git('ls-files','--others','--exclude-standard','-z','--','tests','tools').decode().split('\0')
    with tempfile.TemporaryDirectory(prefix='windrest-patch-verify-') as folder:
        checkout=Path(folder)
        subprocess.run(['git','init','-q',folder],check=True)
        for name in changed:
            result=subprocess.run(['git','show','HEAD:'+name],cwd=ROOT,capture_output=True)
            if result.returncode==0:
                destination=checkout/name;destination.parent.mkdir(parents=True,exist_ok=True);destination.write_bytes(result.stdout)
        patch_path=checkout/'Current-Fixes.patch';patch_path.write_bytes(patch)
        subprocess.run(['git','apply','--check',str(patch_path)],cwd=checkout,check=True)
    readme='''独立测试配置与修复源码包 V4

先将另一台电脑的仓库更新至 cd68f40 或包含该提交的版本，并保留已有未提交修改。
本包不含账号、证书、玩家档、服务器世界或历史测试媒体。

1. 解压到独立临时目录。将 tools 和 tests 中新增文件复制到项目同名目录；已有文件内容不同时保留两份，不直接覆盖。
2. 在项目目录运行 git apply --check <解压目录>/Current-Fixes.patch。
3. 仅在检查成功时运行 git apply <解压目录>/Current-Fixes.patch。检查失败则核对本地改动；禁止强制覆盖或重置。若已应用，先用 git apply --reverse --check 核验，不重复应用。
4. 运行 tools/Independent-Test.ps1 -Action setup -GodotPath <这台电脑的 Godot 4.7.2 路径>。
5. 分别使用 server 和 client 操作启动。每台电脑使用自己的用户目录、账号、证书和世界，重复配置保留已有信息。

本包只是在本机验证了补丁可应用到对应源码；另一台电脑的实际配置和测试尚需在那里执行。
不自动提交或推送。
'''
    with ZipFile(OUTPUT,'x',ZIP_DEFLATED) as archive:
        archive.writestr('Current-Fixes.patch',patch)
        archive.writestr('README.txt',readme.encode('utf-8-sig'))
        archive.writestr('manifest.json',json.dumps({'base':git('rev-parse','HEAD').decode().strip(),'changed':changed,'added':[p for p in added if p]},ensure_ascii=False,indent=2))
        for name in added:
            if name and (ROOT/name).is_file():archive.write(ROOT/name,name)
    print(OUTPUT)

if __name__=='__main__':main()
