"""Read local server telemetry without accessing accounts or gameplay saves."""
import argparse
import json
from pathlib import Path
import socket
import ssl
import threading
import time
import tkinter as tk
from tkinter import ttk


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--config', required=True)
    parser.add_argument('--self-test', action='store_true')
    args = parser.parse_args()
    config_path = Path(args.config).resolve()
    config = json.loads(config_path.read_text(encoding='utf-8-sig'))
    data = (config_path.parent / config['data_dir']).resolve()
    root = tk.Tk()
    root.title('风栖原野 · 服务器实时监控')
    root.geometry('1060x700')
    root.minsize(900, 600)
    style = ttk.Style()
    style.configure('.', font=('Microsoft YaHei UI', 10))
    frame = ttk.Frame(root, padding=18)
    frame.pack(fill='both', expand=True)
    status = tk.StringVar(value='正在读取服务器状态…')
    summary = tk.StringVar()
    probe = tk.StringVar(value='本机 HTTPS 往返：检测中')
    ttk.Label(frame, textvariable=status, font=('Microsoft YaHei UI', 16, 'bold')).pack(anchor='w')
    ttk.Label(frame, textvariable=summary, wraplength=1000).pack(anchor='w', pady=12)
    ttk.Label(frame, textvariable=probe).pack(anchor='w')
    ttk.Label(frame, text='处理耗时包含排队、游戏计算及回复写出；本机往返不代表远端玩家延迟。').pack(anchor='w', pady=(4, 12))
    ttk.Label(frame, text='最近通信地址（同一地址可能包含多位玩家；不是在线人数）').pack(anchor='w')
    clients = ttk.Treeview(frame, columns=('ip','age','op','count','ms','status'), show='headings', height=7)
    for key, title, width in [('ip','连接地址',190),('age','距上次通信',110),('op','最近操作',190),('count','请求次数',100),('ms','处理耗时 ms',130),('status','状态码',90)]:
        clients.heading(key, text=title)
        clients.column(key, width=width, anchor='w')
    clients.pack(fill='x', pady=(6, 14))
    ttk.Label(frame, text='最近通信记录（每秒刷新，最多显示 80 条）').pack(anchor='w')
    events = tk.Text(frame, height=10, state='disabled', font=('Consolas', 10), wrap='none')
    events.pack(fill='both', expand=True, pady=6)
    ttk.Label(frame, text='关闭本窗口不会停止服务器。仅显示接口正文流量，不含 TLS 开销及更新包下载。').pack(anchor='w')
    latest_probe = ['检测中']
    stop = threading.Event()

    def ping():
        while not stop.is_set():
            try:
                context = ssl.create_default_context(cafile=str(data/'server-public.crt'))
                started = time.perf_counter()
                with socket.create_connection(('127.0.0.1', config['port']), timeout=3) as raw:
                    with context.wrap_socket(raw, server_hostname='windrest-server') as conn:
                        conn.sendall(b'GET /monitor-probe HTTP/1.0\r\nHost: windrest-server\r\n\r\n')
                        if not conn.recv(1024):
                            raise OSError('empty reply')
                latest_probe[0] = f'{(time.perf_counter()-started)*1000:.1f} ms（含新建 TLS 连接）'
            except (OSError, ssl.SSLError):
                latest_probe[0] = '无法连接'
            stop.wait(3)

    def refresh():
        try:
            value = json.loads((data/'server-monitor.json').read_text(encoding='utf-8'))
            now = time.time()
            age = now-value['updated']
            status.set(('运行中' if age < 4 else '监控数据已中断') + f"  ·  端口 {config['port']}  ·  PID {value['pid']}")
            uptime = int(now-value['started'])
            players = [p['name'] for p in value.get('players', []) if now-p['last'] < 15]
            summary.set(f"在线角色 {len(players)}：{', '.join(players) or '暂无'}\n"
                        f"运行 {uptime//3600:02d}:{uptime//60%60:02d}:{uptime%60:02d}    正在处理 {value['active']}    请求 {value['total']}    近 5 秒 {value['rate']:.1f} 次/秒    错误/拒绝 {value['errors']}\n"
                        f"接收 {value['received']/1024:.1f} KB    发送 {value['sent']/1024:.1f} KB    近 30 秒处理耗时：中位 {value['p50']:.1f} ms / P95 {value['p95']:.1f} ms")
            clients.delete(*clients.get_children())
            for ip, row in sorted(value['clients'].items()):
                if now-row['last'] < 300:
                    clients.insert('', 'end', values=(ip,f"{now-row['last']:.0f} 秒",row['operation'],row['count'],f"{row['milliseconds']:.1f}",row['status']))
            events.configure(state='normal')
            events.delete('1.0','end')
            for row in reversed(value['events']):
                stamp = time.strftime('%H:%M:%S', time.localtime(row['time']))
                events.insert('end', f"{stamp}  {row['ip']:<16} {row['operation']:<22} {row['status']}  {row['ms']:8.1f} ms\n")
            events.configure(state='disabled')
        except (OSError, ValueError, KeyError):
            status.set('等待服务器监控数据 · 服务器可能尚未启动')
        probe.set('本机 HTTPS 往返：'+latest_probe[0])
        root.after(1000, refresh)

    def close():
        stop.set()
        root.destroy()

    root.protocol('WM_DELETE_WINDOW', close)
    threading.Thread(target=ping, daemon=True).start()
    refresh()
    if args.self_test:
        def check():
            assert root.winfo_viewable()
            assert '运行中' in status.get(), status.get()
            print('MONITOR_WINDOW_PASS', flush=True)
            close()
        root.after(1500, check)
    root.mainloop()


if __name__ == '__main__':
    main()
