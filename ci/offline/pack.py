import struct, base64, json, hashlib
from pathlib import Path

def central(buf):
    end=buf.rfind(b'PK\x05\x06', -65557)
    if end<0 or end+22+int.from_bytes(buf[end+20:end+22],'little')!=len(buf):
        raise ValueError("invalid end of central directory")
    return end, struct.unpack_from('<I',buf,end+16)[0]

def digest(buf): return hashlib.sha256(buf).hexdigest()

def describe(un, sig):
    a, b = un.read_bytes(), sig.read_bytes()
    eu,cu=central(a)
    es,cs=central(b)
    assert a[:cu]==b[:cu], 'ZIP payload changed'
    assert a[cu:eu]==b[cs:es], 'central records changed'
    assert a[eu:eu+16]==b[es:es+16] and a[eu+20:]==b[es+20:], 'ZIP end changed'
    return dict(input_sha256=digest(a),signed_sha256=digest(b),block=base64.b64encode(b[cu:cs]).decode())

def attach(un, out, spec):
    a=un.read_bytes()
    assert digest(a)==spec['input_sha256']
    e,c=central(a)
    block=base64.b64decode(spec['block'],validate=True)
    data=a[:c]+block+a[c:e+16]+struct.pack('<I',c+len(block))+a[e+20:]
    assert digest(data)==spec['signed_sha256']
    out.write_bytes(data)

if __name__=='__main__':
    import sys
    names=['fixture','game']
    unsigned=[Path('fixture.apk'),Path('VectorRange-unsigned.apk')]
    signed=[Path('previous.apk'),Path('VectorRange-0.2.0-release-arm64.apk')]
    if sys.argv[1]=='collect':
        Path('signatures.json').write_text(json.dumps({n:describe(u,s) for n,u,s in zip(names,unsigned,signed)},indent=2)+'\n')
    else:
        spec=json.loads(Path('signatures.json').read_text())
        for n,u,s in zip(names,unsigned,signed): attach(u,s,spec[n])
