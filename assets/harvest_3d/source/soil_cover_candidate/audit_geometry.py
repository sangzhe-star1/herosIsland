"""Audit source GLB geometry without changing it; write a JSON report beside it."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--out', type=Path, default=Path(__file__).resolve().parent)
args = parser.parse_args()
out = args.out.resolve()
raw = (out/'soil_cover.glb').read_bytes()
magic, version, declared = struct.unpack_from('<III',raw)
assert magic == 0x46546c67 and version == 2 and declared == len(raw)
offset = 12
document = None
binary = b''
while offset<len(raw):
    size, kind = struct.unpack_from('<II',raw,offset)
    chunk = raw[offset+8:offset+8+size]
    assert len(chunk)==size
    if kind==0x4e4f534a:
        document = json.loads(chunk)
    if kind==0x004e4942:
        binary = chunk
    offset += size+8
assert document
accessors = document['accessors']
views = document['bufferViews']
def decoded(accessor_id):
    accessor = accessors[accessor_id]
    assert 'sparse' not in accessor
    view = views[accessor['bufferView']]
    assert view.get('buffer',0)==0
    fmt, byte_size = {5121:('B',1),5123:('H',2),5125:('I',4),5126:('f',4)}[accessor['componentType']]
    channels = {'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[accessor['type']]
    stride = view.get('byteStride',channels*byte_size)
    start = view.get('byteOffset',0)+accessor.get('byteOffset',0)
    assert stride>=channels*byte_size
    assert start+(accessor['count']-1)*stride+channels*byte_size<=len(binary)
    return [struct.unpack_from('<'+fmt*channels,binary,start+i*stride) for i in range(accessor['count'])]

primitives = []
totals = {'vertices':0,'triangles':0,'nonfinite_positions':0,'nonfinite_normals':0,
          'zero_normals':0,'nonunit_normals':0,'invalid_indices':0,
          'degenerate_triangles':0,'opposed_face_normals':0}
all_positions = []
for mesh in document['meshes']:
    for primitive in mesh['primitives']:
        assert primitive.get('mode',4)==4
        assert 0<=primitive['material']<len(document['materials'])
        positions = decoded(primitive['attributes']['POSITION'])
        normals = decoded(primitive['attributes']['NORMAL'])
        indices = [row[0] for row in decoded(primitive['indices'])]
        assert len(indices)%3==0 and len(positions)==len(normals)
        item = dict.fromkeys(totals,0)
        item['vertices'],item['triangles'] = len(positions),len(indices)//3
        item['nonfinite_positions'] = sum(not all(math.isfinite(x) for x in p) for p in positions)
        item['nonfinite_normals'] = sum(not all(math.isfinite(x) for x in n) for n in normals)
        item['zero_normals'] = sum(sum(x*x for x in n)<1e-10 for n in normals)
        item['nonunit_normals'] = sum(abs(sum(x*x for x in n)-1)>.001 for n in normals)
        item['invalid_indices'] = sum(not 0<=i<len(positions) for i in indices)
        for index in range(0,len(indices),3):
            ids = indices[index:index+3]
            a,b,c = [positions[i] for i in ids]
            ab,ac = [b[i]-a[i] for i in range(3)],[c[i]-a[i] for i in range(3)]
            cross = [ab[1]*ac[2]-ab[2]*ac[1],ab[2]*ac[0]-ab[0]*ac[2],ab[0]*ac[1]-ab[1]*ac[0]]
            area_squared = sum(x*x for x in cross)
            if area_squared<1e-18:
                item['degenerate_triangles']+=1
            average = [sum(normals[i][axis] for i in ids) for axis in range(3)]
            if sum(cross[i]*average[i] for i in range(3)) < -1e-10:
                item['opposed_face_normals']+=1
        for key,value in item.items():
            totals[key]+=value
        primitives.append({'mesh':mesh.get('name'),**item})
        all_positions.extend(positions)
for key,value in totals.items():
    if key not in ('vertices','triangles'):
        assert value==0, (key,value)
assert not document.get('textures') and not document.get('images') and not document.get('animations')
assert not document.get('cameras') and not document.get('skins')
glb_audit = {'sha256':hashlib.sha256(raw).hexdigest(),'bytes':len(raw),
    'nodes':len(document['nodes']),'meshes':len(document['meshes']),
    'materials':len(document['materials']),'textures':len(document.get('textures',[])),
    'images':len(document.get('images',[])),'animations':len(document.get('animations',[])),
    'totals':totals,'primitives':primitives,
    'local_bounds_gltf_y_up':[list(map(min,zip(*all_positions))),list(map(max,zip(*all_positions)))],
    'materials_detail':[{'name':m['name'],'pbr':m.get('pbrMetallicRoughness',{}),
                         'alpha_mode':m.get('alphaMode','OPAQUE')} for m in document['materials']]}
(out/'glb_audit.json').write_text(json.dumps(glb_audit,indent=2)+'\n')


print(json.dumps(glb_audit['totals'],indent=2))
