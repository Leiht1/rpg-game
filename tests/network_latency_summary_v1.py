"""Summarize audit artifacts without credentials or production player data."""
import collections,csv,json,statistics
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'reports/network-latency-full-v1'
def stats(v):
    v=sorted(v)
    return dict(n=len(v),p50=round(statistics.median(v),3),p95=round(v[int((len(v)-1)*.95)],3),maximum=round(v[-1],3)) if v else {}
def main():
    local=[]
    for p in OUT.glob('controlled*-tls.json'):local.extend(json.loads(p.read_text(encoding='utf-8'))['samples'])
    public={}
    for p in sorted(OUT.glob('public-soak-*.json')):
        d=json.loads(p.read_text(encoding='utf-8'))
        ix={r['request_id']:r for r in d['channel'] if r['request_id']}
        actions=[r for r in d['actions'] if r['operation']!='local_ui' and r['ok'] and not r['label'].startswith('attempt_')]
        paired=[(r,ix[r['request_id']]) for r in actions if r['request_id'] in ix]
        public[p.stem]=dict(api_ms={k:stats(v) for k,v in d['api_ms'].items()},
            command_confirm_ms=stats([r['confirm_ms'] for r in actions]),
            pre_api_ms=stats([(net['queued_us']-a['began_us'])/1000 for a,net in paired]),
            http_lane_ms=stats([(r['sent_us']-r['queued_us'])/1000 for a,r in paired]),
            request_decode_ms=stats([(r['completed_us']-r['sent_us'])/1000 for a,r in paired]),
            snapshot_apply_ms=stats([r['apply_ms'] for r in d['snapshot_apply']]),
            frame_ms=stats(d['frame_ms']),max_move_ack_age_ms=d['max_move_ack_age_ms'],prediction_blocked_frames=d['prediction_blocked_frames'],
            http_body_bytes=stats([r['http_body_bytes'] for r in d['channel'] if 'http_body_bytes' in r]),decoded_bytes=stats([r['decoded_bytes'] for r in d['channel']]),
            rejected_actions=[dict(label=r['label'],error=r.get('error','')) for r in d['actions'] if not r['ok']])
    coverage=[]
    for operation in sorted({r['scenario'].split(':',1)[0] for r in local}):
        for count in (1,2,4):
            group=[r for r in local if r['scenario'].split(':',1)[0]==operation and r['players']==count]
            accepted=[r for r in group if r['ok']]
            coverage.append(dict(operation=operation,callers=count,success=len(accepted),rejected=len(group)-len(accepted),**stats([r['end_to_end_ms'] for r in accepted])))
    with (OUT/'coverage.csv').open('w',encoding='utf-8-sig',newline='') as f:
        w=csv.DictWriter(f,fieldnames=['operation','callers','success','rejected','n','p50','p95','maximum']);w.writeheader();w.writerows(coverage)
    remote=[]
    paths=sorted(OUT.glob('public-remote-2-*.json'))
    if len(paths)==2:
        clients=[json.loads(p.read_text(encoding='utf-8')) for p in paths]
        for i,d in enumerate(clients):
            other=clients[1-i]
            for a in d['actions']:
                if a['operation']!='combat_attack' or not a['ok']:continue
                after=a['sent_at_us']
                peer=[r for r in other['remote_changes'] if r.get('player_id')==d.get('self_player_id') and r.get('attacking') and after<=r['at_us']<=after+3000000]
                own=[r for r in d.get('local_visual_events',[]) if r['attacking'] and after<=r['at_us']<=after+1000000]
                remote.append(dict(client=i,label=a['label'],confirm_ms=a['confirm_ms'],local_visual_ms=(own[0]['at_us']-after)/1000 if own else None,peer_visual_ms=(peer[0]['at_us']-after)/1000 if peer else None))
    summary=dict(local_requests=len(local),local_http_500=sum(r['status']>=500 for r in local),
        local_by_callers={str(n):dict(all=stats([r['end_to_end_ms'] for r in local if r['players']==n]),accepted=stats([r['end_to_end_ms'] for r in local if r['players']==n and r['ok']]),rejected=sum(r['players']==n and not r['ok'] for r in local)) for n in (1,2,4)},
        active_command_operations=sorted({r['scenario'].split(':',1)[0] for r in local if r['ok']}),public=public,peer_observation=remote)
    (OUT/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(summary,ensure_ascii=False,indent=2))
if __name__=='__main__':main()
