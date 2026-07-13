import numpy as np, open3d as o3d, sys
D="/private/tmp/claude-501/-Users-tanumashuu-Documents-Codex-2026-06-24-handoff-next-chat-2026-06-24-work-taste-glass-native-ai-samples/bc3ee124-756d-4cb2-8fbc-8bda762514a0/scratchpad/"

# 元の切り抜きPLY（ガウシアン）から x,y,z + 色を再取得（掃除前の密な点を使う）
raw="/Users/tanumashuu/Downloads/無題のスキャン 2.ply"
data=open(raw,'rb').read(); he=data.index(b'end_header\n')+len(b'end_header\n')
props=[l.split()[-1] for l in data[:he].decode('ascii','ignore').splitlines() if l.startswith('property float')]
n=int([l for l in data[:he].decode().splitlines() if l.startswith('element vertex')][0].split()[-1])
buf=np.frombuffer(data[he:he+n*4*len(props)],dtype=np.float32).reshape(n,len(props)).astype(np.float64)
gi=lambda k:props.index(k)
xyz=buf[:,[gi('x'),gi('y'),gi('z')]]*1000
C0=0.28209479177387814
rgb=np.clip(0.5+C0*buf[:,[gi('f_dc_0'),gi('f_dc_1'),gi('f_dc_2')]],0,1)
op=1/(1+np.exp(-buf[:,gi('opacity')]))
m=(op>0.2)&np.isfinite(xyz).all(1); xyz,rgb=xyz[m],rgb[m]
c=np.median(xyz,0); r=np.linalg.norm(xyz-c,axis=1); k=r<np.percentile(r,96); xyz,rgb=xyz[k],rgb[k]
print("入力点数:",len(xyz))

pcd=o3d.geometry.PointCloud()
pcd.points=o3d.utility.Vector3dVector(xyz)
pcd.colors=o3d.utility.Vector3dVector(rgb)
pcd=pcd.voxel_down_sample(voxel_size=2.0)
pcd,_=pcd.remove_statistical_outlier(nb_neighbors=20,std_ratio=2.0)
pcd.estimate_normals(o3d.geometry.KDTreeSearchParamHybrid(radius=8,max_nn=30))
pcd.orient_normals_consistent_tangent_plane(15)
print("メッシュ化中の点数:",len(pcd.points))

mesh,dens=o3d.geometry.TriangleMesh.create_from_point_cloud_poisson(pcd,depth=9)
dens=np.asarray(dens)
mesh.remove_vertices_by_mask(dens<np.quantile(dens,0.06))  # 低密度=でっち上げ面を削る
mesh=mesh.filter_smooth_simple(number_of_iterations=2)
mesh.compute_vertex_normals()
print("メッシュ: 頂点",len(mesh.vertices),"面",len(mesh.triangles))
o3d.io.write_triangle_mesh(D+"buzz_mesh.ply",mesh)
print("saved",D+"buzz_mesh.ply")
