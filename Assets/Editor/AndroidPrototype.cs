using System;
using System.IO;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace VectorRange.Editor
{
    public static class AndroidPrototype
    {
        const string DepotScene = "Assets/Scenes/Depot.unity";
        const string Pipeline = "Assets/Settings/DepotURP.asset";

        [InitializeOnLoadMethod]
        static void OnProjectOpen() => EditorApplication.delayCall += ApplyPipeline;

        static void ApplyPipeline()
        {
            var asset = AssetDatabase.LoadAssetAtPath<UniversalRenderPipelineAsset>(Pipeline);
            if (asset && GraphicsSettings.defaultRenderPipeline != asset)
                GraphicsSettings.defaultRenderPipeline = asset;
        }

        [MenuItem("Vector Range/Validate prototype")]
        public static void Validate()
        {
            ApplyPipeline();
            if (!AssetDatabase.LoadAssetAtPath<SceneAsset>(DepotScene) ||
                !Resources.Load<Shader>("DepotSurface") ||
                !(GraphicsSettings.defaultRenderPipeline is UniversalRenderPipelineAsset pipeline) ||
                pipeline.scriptableRenderer == null)
                throw new BuildFailedException("Depot scene, surface shader or URP renderer is missing.");
            var round = new TimeAttack();
            round.Start();
            round.Shoot(true); round.Shoot(false); round.Tick(1);
            round.Pause(); round.Tick(60); round.Shoot(true);
            Require(round.Remaining==29 && round.Score==100 && round.Shots==2);
            round.Resume(); round.Tick(31); round.Shoot(true);
            Require(round.State==RoundState.Finished && round.Remaining==0 && round.Accuracy==50 && round.Score==100);
            round.Start();
            Require(round.State==RoundState.Running && round.Remaining==30 && round.Shots==0 && round.Accuracy==0);
            Debug.Log("Vector Range prototype validation passed.");
        }

        static void Require(bool condition)
        {
            if (!condition) throw new BuildFailedException("Time attack smoke check failed.");
        }

        [MenuItem("Vector Range/Build Android APK")]
        public static void BuildAndroid()
        {
            if (!BuildPipeline.IsBuildTargetSupported(BuildTargetGroup.Android,BuildTarget.Android))
                throw new BuildFailedException("Install Android Build Support, SDK, NDK and OpenJDK in Unity Hub.");
            if (EditorUserBuildSettings.activeBuildTarget != BuildTarget.Android &&
                !EditorUserBuildSettings.SwitchActiveBuildTarget(BuildTargetGroup.Android,BuildTarget.Android))
                throw new BuildFailedException("Activate Android in Build Profiles or pass -buildTarget Android.");
            Validate();
            PlayerSettings.productName="Vector Range";
            PlayerSettings.companyName="Vector Range";
            PlayerSettings.defaultInterfaceOrientation=UIOrientation.LandscapeLeft;
            PlayerSettings.SetApplicationIdentifier(NamedBuildTarget.Android,"com.jjongjjongs.vectorrange");
            PlayerSettings.SetScriptingBackend(NamedBuildTarget.Android,ScriptingImplementation.IL2CPP);
            PlayerSettings.Android.targetArchitectures=AndroidArchitecture.ARM64;
            EditorUserBuildSettings.buildAppBundle=false;
            Directory.CreateDirectory("Builds/Android");
            var report=BuildPipeline.BuildPlayer(new BuildPlayerOptions {
                scenes=new[]{DepotScene}, target=BuildTarget.Android,
                locationPathName="Builds/Android/VectorRange.apk", options=BuildOptions.None
            });
            if (report.summary.result!=BuildResult.Succeeded)
                throw new BuildFailedException("Android build failed. See the Unity editor log.");
            Debug.Log("APK created at "+Path.GetFullPath(report.summary.outputPath));
        }
    }
}
