using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace VectorRange
{
    // All baked scenery uses a single combined mesh per palette color.
    public sealed class Depot
    {
        readonly Transform room;
        readonly Dictionary<string, Material> palette = new Dictionary<string, Material>();
        readonly Dictionary<Material, List<MeshFilter>> scenery = new Dictionary<Material, List<MeshFilter>>();
        readonly List<GameObject> ornaments = new List<GameObject>();
        readonly List<Mesh> batches = new List<Mesh>();
        readonly Shader shader;
        const string Steel = "32464E", Dark = "1D2F35", Wall = "51636A", Floor = "566269";
        const string Amber = "F4A039", Mint = "52E9C7", Cream = "F0E2C8", Orange = "DC7227";
        public readonly List<Collider> Plates = new List<Collider>();
        readonly List<Renderer> faces = new List<Renderer>();
        public Transform ViewModel { get; private set; }

        public Depot(Transform parent)
        {
            room = parent;
            shader = Resources.Load<Shader>("DepotSurface");
            BuildHall();
            BakeScenery();
        }

        Material Paint(string hex, bool glow = false)
        {
            string key = hex + (glow ? "*" : "");
            if (palette.TryGetValue(key, out var material)) return material;
            ColorUtility.TryParseHtmlString("#" + hex, out var tint);
            material = new Material(shader) { name = key, enableInstancing = true };
            material.SetColor("_BaseColor", tint);
            material.SetFloat("_Glow", glow ? 1f : 0f);
            palette.Add(key, material);
            return material;
        }

        GameObject Shape(string name, PrimitiveType type, Vector3 pos, Vector3 size, string color,
            bool solid = false, bool glow = false, Transform parent = null, bool batch = true)
        {
            var go = GameObject.CreatePrimitive(type);
            go.name = name;
            go.transform.SetParent(parent ? parent : room, false);
            go.transform.localPosition = pos;
            go.transform.localScale = size;
            var renderer = go.GetComponent<MeshRenderer>();
            var material = Paint(color, glow);
            renderer.sharedMaterial = material;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
            renderer.receiveShadows = false;
            if (!solid)
            {
                var collider = go.GetComponent<Collider>();
                collider.enabled = false;
                Object.Destroy(collider);
            }
            if (batch)
            {
                if (!scenery.TryGetValue(material, out var list)) scenery[material] = list = new List<MeshFilter>();
                list.Add(go.GetComponent<MeshFilter>());
                if (!solid) ornaments.Add(go);
            }
            return go;
        }

        GameObject Box(string name, float x, float y, float z, float w, float h, float d, string color,
            bool solid = false, bool glow = false)
            => Shape(name, PrimitiveType.Cube, new Vector3(x,y,z), new Vector3(w,h,d), color, solid, glow);

        void BuildHall()
        {
            Box("Concrete slab",0,-0.15f,8,20,0.3f,34,Floor,true);
            Box("West wall",-10,3,8,0.4f,6,34,Wall,true);
            Box("East wall",10,3,8,0.4f,6,34,Wall,true);
            Box("End wall",0,3,25,20,6,0.4f,Wall,true);
            Box("Entrance wall",0,3,-9,20,6,0.4f,Wall,true);
            Box("Roof",0,6.1f,8,20,0.2f,34,Dark);
            for (int z = -6; z <= 24; z += 5)
            {
                Box("Roof truss",0,5.75f,z,20,0.32f,0.26f,Steel);
                Box("Strip light",0,5.55f,z,6,0.08f,0.18f,Cream,false,true);
                foreach (int side in new[] {-1,1})
                {
                    Box("Steel column",side*9.65f,2.9f,z,0.35f,5.8f,0.5f,Steel);
                    Box("Warning band",side*9.43f,1.7f,z,0.09f,0.22f,0.6f,Amber);
                    Box("Floor seam",side*5,0.008f,z,9.8f,0.012f,0.025f,Dark);
                }
            }
            foreach (int x in new[] {-6,6}) Box("Lane edge",x,0.014f,7,0.09f,0.015f,28,Amber);
            for (int z = -4; z < 22; z += 3) Box("Lane markers",0,0.022f,z,0.12f,0.018f,1.25f,Amber);
            foreach (int side in new[] {-1,1})
            {
                Box("Side gantry",side*8.6f,3.1f,12,2.35f,0.28f,18,Steel,true);
                Box("Rail",side*7.5f,4.12f,12,0.08f,0.09f,18,Amber);
                for (int z=3;z<=21;z+=3) Box("Rail posts",side*7.5f,3.62f,z,0.08f,1,0.08f,Amber);
                Box("Barrier",side*4,0.52f,5.5f,2.5f,1.04f,1,Wall,true);
                Box("Barrier stripe",side*4,0.67f,4.985f,2.5f,0.14f,0.02f,Amber);
            }
            Box("End door",0,2.2f,24.7f,6.4f,4.4f,0.18f,Dark);
            for (int i=0;i<9;i++) Box("Shutter slats",0,0.45f+i*0.43f,24.58f,6,0.04f,0.08f,Steel);
            Target(0,1.5f,9); Target(-4,2.05f,13); Target(4.8f,2.45f,15);
            Target(-2.4f,1.65f,18.2f); Target(2.2f,3.1f,21);
        }

        void Target(float x, float y, float z)
        {
            Box("Plinth",x,0.14f,z,1,0.28f,0.85f,Dark,true);
            Box("Post",x,y/2,z,0.22f,y,0.22f,Steel,true);
            var disc = Shape("Electronic plate",PrimitiveType.Cylinder,new Vector3(x,y,z),
                new Vector3(1.45f,0.10f,1.45f),Dark,false,false,null,false);
            disc.transform.localRotation = Quaternion.Euler(90,0,0);
            // A cylinder primitive uses a capsule collider. Fit the scoring plane with its circular mesh.
            var plane = disc.AddComponent<MeshCollider>();
            plane.sharedMesh = disc.GetComponent<MeshFilter>().sharedMesh;
            Plates.Add(plane);
            faces.Add(DiscLayer(x,y,z-0.115f,1.30f,Mint));
            DiscLayer(x,y,z-0.139f,0.96f,Dark);
            DiscLayer(x,y,z-0.163f,0.64f,Cream);
            DiscLayer(x,y,z-0.187f,0.32f,Dark);
        }

        Renderer DiscLayer(float x,float y,float z,float diameter,string color)
        {
            var layer = Shape("Target ring",PrimitiveType.Cylinder,new Vector3(x,y,z),
                new Vector3(diameter,0.009f,diameter),color,false,true,null,false);
            layer.transform.localRotation = Quaternion.Euler(90,0,0);
            return layer.GetComponent<Renderer>();
        }

        public void LightPlate(int index,bool on) => faces[index].sharedMaterial = Paint(on ? Amber : Mint,true);

        void BakeScenery()
        {
            foreach (var group in scenery)
            {
                var parts = new CombineInstance[group.Value.Count];
                for (int i=0;i<parts.Length;i++)
                {
                    var filter = group.Value[i];
                    parts[i].mesh = filter.sharedMesh;
                    parts[i].transform = room.worldToLocalMatrix * filter.transform.localToWorldMatrix;
                    filter.GetComponent<MeshRenderer>().enabled = false;
                }
                var mesh = new Mesh { name = "Depot " + group.Key.name };
                mesh.CombineMeshes(parts);
                batches.Add(mesh);
                var go = new GameObject(mesh.name,typeof(MeshFilter),typeof(MeshRenderer));
                go.transform.SetParent(room,false);
                go.GetComponent<MeshFilter>().sharedMesh = mesh;
                go.GetComponent<MeshRenderer>().sharedMaterial = group.Key;
            }
            foreach(var go in ornaments) Object.Destroy(go);
            scenery.Clear();
            ornaments.Clear();
        }

        public void BuildViewModel(Transform camera)
        {
            ViewModel = new GameObject("First person model").transform;
            ViewModel.SetParent(camera,false);
            var weapon = new GameObject("Pulse").transform;
            weapon.SetParent(ViewModel,false);
            var hands = new GameObject("Gloves").transform;
            hands.SetParent(ViewModel,false);
            Part(weapon,"Cream shell",0,0,0.17f,0.13f,0.14f,0.39f,Cream);
            Part(weapon,"Lower frame",0,-0.07f,0.14f,0.118f,0.07f,0.36f,Dark);
            Part(weapon,"Amber cap",0,0,-0.03f,0.13f,0.14f,0.075f,Orange);
            Part(weapon,"Charge strip",0,0.076f,0.13f,0.035f,0.012f,0.22f,Mint);
            Part(hands,"Palm",0,-0.12f,0.02f,0.12f,0.10f,0.17f,Dark);
            Part(hands,"Cuff",0.018f,-0.16f,-0.08f,0.15f,0.11f,0.14f,Steel);
        }

        void Part(Transform parent,string name,float x,float y,float z,float w,float h,float d,string tint)
            => Shape(name,PrimitiveType.Cube,new Vector3(x,y,z),new Vector3(w,h,d),tint,false,tint==Mint,parent,false);

        public void Dispose()
        {
            foreach(var mat in palette.Values) Object.Destroy(mat);
            foreach(var mesh in batches) Object.Destroy(mesh);
        }
    }
}
