import json,os,re,sys
root=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
manifest=json.load(open(os.path.join(root,'assets','books','manifest.json'),encoding='utf-8'))
learning=json.load(open(os.path.join(root,'assets','data','book_learning.json'),encoding='utf-8'))['chapters']
refs=json.load(open(os.path.join(root,'assets','data','quick_ref_items.json'),encoding='utf-8'))
ref_ids={r[0] for r in refs['rows']}
tool_ids={'fit','chain','cpk','weight','unit','torque','gdnt'}
chapter_keys={c['key'] for b in manifest['books'] for c in b['chapters']}
errors=[]; warnings=[]
for b in manifest['books']:
    for c in b['chapters']:
        path=os.path.join(root,'assets','books',c['file'])
        if not os.path.exists(path): errors.append('missing book file '+c['file']); continue
        text=open(path,encoding='utf-8').read()
        if len(text.strip())<200: warnings.append('short chapter '+c['key'])
        if '待核对' in text: errors.append('待核对 remains in '+c['key'])
for key,item in learning.items():
    if key not in chapter_keys: errors.append('learning key not in manifest: '+key)
    if not item.get('summary'): errors.append('empty summary: '+key)
    quiz=item.get('quiz',[])
    if len(quiz)<3: warnings.append('quiz <3: '+key)
    for qi,q in enumerate(quiz):
        opts=q.get('options',[])
        a=q.get('answer',-1)
        if len(opts)<2 or not isinstance(a,int) or a<0 or a>=len(opts):
            errors.append(f'bad quiz {key} q{qi+1}')
    for k in item.get('see_also',[]):
        if k not in chapter_keys: errors.append('bad see_also '+key+' -> '+k)
    for r in item.get('quick_refs',[]):
        if r not in ref_ids: errors.append('bad quick_ref '+key+' -> '+r)
    for t in item.get('related_tools',[]):
        if t not in tool_ids: errors.append('bad tool '+key+' -> '+t)
print(f'chapters={len(chapter_keys)} learning={len(learning)} quick_refs={len(ref_ids)}')
print(f'errors={len(errors)} warnings={len(warnings)}')
for e in errors: print('ERROR',e)
for w in warnings[:20]: print('WARN',w)
sys.exit(1 if errors else 0)
