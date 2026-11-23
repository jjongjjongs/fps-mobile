using System;
using UnityEngine;
using UnityEngine.UI;

namespace VectorRange
{
    public sealed class RangeHud : MonoBehaviour
    {
        enum Page { Home, Setup, Armory, Records, Settings, Play, Pause, Result }
        static readonly Color Ink = new Color32(14,29,35,244);
        static readonly Color Slate = new Color32(39,62,70,250);
        static readonly Color Paper = new Color32(246,239,217,255);
        static readonly Color Mint = new Color32(100,242,201,255);
        static readonly Color Amber = new Color32(255,168,54,255);
        static readonly Color Glass = new Color32(18,31,38,166);
        static readonly Vector2 Center = new Vector2(.5f,.5f), Left = new Vector2(0,.5f);
        static readonly Vector2 Top = new Vector2(.5f,1), TopRight = Vector2.one;
        static readonly Vector2 BottomLeft = Vector2.zero, BottomRight = Vector2.right;
        RangeGame game;
        RectTransform canvasRect, safe, page, reticle;
        Rect oldSafe;
        Vector2Int oldSize;
        Font font;
        Sprite circle;
        Texture2D circlePixels;
        Text score, timer, charge, flash;
        Image dot;
        Page current;
        bool pausedSettings;
        int oldSeconds, oldScore, oldCharge, oldRechargeStep;
        bool oldFlash, oldOnPlate;

        public void Build(RangeGame owner)
        {
            game=owner;
            var go = new GameObject("Landscape interface",typeof(RectTransform),typeof(Canvas),typeof(CanvasScaler),typeof(GraphicRaycaster));
            go.transform.SetParent(transform,false);
            canvasRect=(RectTransform)go.transform;
            go.GetComponent<Canvas>().renderMode=RenderMode.ScreenSpaceOverlay;
            var scale=go.GetComponent<CanvasScaler>();
            scale.uiScaleMode=CanvasScaler.ScaleMode.ScaleWithScreenSize;
            scale.referenceResolution=new Vector2(960,540);
            scale.screenMatchMode=CanvasScaler.ScreenMatchMode.Expand;
            safe=Rect("Safe area",canvasRect);
            font=Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
            circle=MakeCircle();
            LayoutSafeArea();
        }

        void LateUpdate() => LayoutSafeArea();

        void LayoutSafeArea()
        {
            var r=Screen.safeArea;
            var size=new Vector2Int(Screen.width,Screen.height);
            if (size.x==0 || size.y==0 || (oldSafe==r && oldSize==size)) return;
            oldSafe=r; oldSize=size;
            safe.anchorMin=new Vector2(r.xMin/size.x,r.yMin/size.y);
            safe.anchorMax=new Vector2(r.xMax/size.x,r.yMax/size.y);
            safe.offsetMin=safe.offsetMax=Vector2.zero;
        }

        Sprite MakeCircle()
        {
            const int n=96;
            circlePixels=new Texture2D(n,n,TextureFormat.RGBA32,false);
            var pixels=new Color32[n*n];
            for(int y=0;y<n;y++)
                for(int x=0;x<n;x++)
                {
                    float d=Vector2.Distance(new Vector2(x+.5f,y+.5f),new Vector2(n/2f,n/2f));
                    pixels[y*n+x]=new Color(1,1,1,Mathf.Clamp01(n/2f-d));
                }
            circlePixels.SetPixels32(pixels);
            circlePixels.wrapMode=TextureWrapMode.Clamp;
            circlePixels.Apply(false,true);
            return Sprite.Create(circlePixels,new Rect(0,0,n,n),Center,100);
        }

        static RectTransform Rect(string name,Transform parent)
        {
            var r=(RectTransform)new GameObject(name,typeof(RectTransform)).transform;
            r.SetParent(parent,false);
            return r;
        }

        static void Stretch(RectTransform r)
        {
            r.anchorMin=Vector2.zero; r.anchorMax=Vector2.one;
            r.offsetMin=r.offsetMax=Vector2.zero;
        }

        static RectTransform Box(Transform parent,string name,Vector2 anchor,float x,float y,float w,float h)
        {
            var r=Rect(name,parent);
            r.anchorMin=r.anchorMax=anchor;
            r.anchoredPosition=new Vector2(x,y);
            r.sizeDelta=new Vector2(w,h);
            return r;
        }

        static Image Fill(RectTransform r,Color color,bool interactive=false)
        {
            var image=r.gameObject.AddComponent<Image>();
            image.color=color;
            image.raycastTarget=interactive;
            return image;
        }

        Text Label(RectTransform parent,string value,int size,Color color,TextAnchor align=TextAnchor.MiddleCenter)
        {
            var r=Rect("Text",parent); Stretch(r);
            var label=r.gameObject.AddComponent<Text>();
            label.font=font; label.fontSize=size; label.fontStyle=FontStyle.Bold;
            label.alignment=align; label.color=color; label.text=value;
            label.horizontalOverflow=HorizontalWrapMode.Overflow;
            label.raycastTarget=false;
            return label;
        }

        Text Line(RectTransform parent,string value,int size,Color color,float x,float y,float w,float h)
            => Label(Box(parent,value,Center,x,y,w,h),value,size,color,TextAnchor.MiddleLeft);

        void Button(RectTransform parent,string title,Vector2 anchor,float x,float y,float w,float h,
            Action action,bool primary=false)
        {
            var r=Box(parent,title,anchor,x,y,w,h);
            var bg=Fill(r,primary?Amber:Slate,true);
            var button=r.gameObject.AddComponent<Button>();
            button.targetGraphic=bg;
            button.navigation=new Navigation { mode=Navigation.Mode.None };
            button.onClick.AddListener(()=>action());
            Label(r,title,20,primary?Ink:Paper);
        }

        void Begin(Page next)
        {
            if (page) { page.gameObject.SetActive(false); Destroy(page.gameObject); }
            if (reticle) { reticle.gameObject.SetActive(false); Destroy(reticle.gameObject); reticle=null; }
            current=next;
            page=Rect(next.ToString(),safe); Stretch(page);
        }

        RectTransform Card(string eyebrow,string title)
        {
            var card=Box(page,"Menu",Left,216,0,362,424);
            Fill(card,Ink);
            Fill(Box(card,"Accent",Center,-174,0,5,424),Amber);
            Line(card,eyebrow,15,Mint,0,165,300,26);
            Line(card,title,37,Paper,0,118,300,77);
            return card;
        }

        void Row(RectTransform card,string title,float y,Action action,bool primary=false)
            => Button(card,title,Center,0,y,300,50,action,primary);

        public void ShowHome()
        {
            game.PreviewPulse(false);
            Begin(Page.Home);
            var card=Card("DEPOT   /   TRAINING HALL","VECTOR RANGE");
            Row(card,"PLAY",36,Setup,true);
            Row(card,"ARMORY",-25,Armory);
            Row(card,"RECORDS",-86,Records);
            Row(card,"SETTINGS",-147,()=>Settings(false));
        }

        void Setup()
        {
            Begin(Page.Setup);
            var card=Card("PLAY   /   DEPOT","TIME ATTACK");
            Line(card,"30 SEC     /     +100 PER HIT",19,Mint,0,43,300,34);
            Line(card,"Equipment   /   PULSE",19,Paper,0,-4,300,34);
            Row(card,"START RUN",-81,game.StartRun,true);
            Row(card,"BACK",-145,ShowHome);
        }

        void Armory()
        {
            Begin(Page.Armory);
            game.PreviewPulse(true);
            var card=Card("ARMORY   /   EQUIPPED","PULSE");
            Line(card,"5 charges    /    Auto recharge",19,Paper,0,35,300,45);
            Line(card,"Tap the pulse button to fire.",17,Mint,0,-13,300,38);
            Row(card,"BACK",-145,ShowHome);
        }

        void Records()
        {
            Begin(Page.Records);
            var card=Card("LOCAL RECORDS","PERSONAL BEST");
            Line(card,"Top score     "+game.Best,23,Amber,0,35,300,45);
            Line(card,"Best accuracy     "+game.BestAccuracy+"%",20,Paper,0,-18,300,45);
            Row(card,"BACK",-145,ShowHome);
        }

        void Settings(bool fromPause)
        {
            Begin(Page.Settings);
            pausedSettings=fromPause;
            var card=Card("PREFERENCES","SETTINGS");
            Row(card,"SOUND     "+(game.Sound?"ON":"OFF"),30,()=>{ game.ToggleSound(); Settings(fromPause); });
            string[] choices={"LOW","NORMAL","HIGH"};
            Row(card,"LOOK     "+choices[game.Sensitivity],-32,()=>{ game.ChangeSensitivity(); Settings(fromPause); });
            Row(card,"BACK",-145,Back);
        }

        TouchPad Pad(RectTransform parent,TouchPad.Kind kind)
        {
            var p=parent.gameObject.AddComponent<TouchPad>();
            p.Game=game; p.Mode=kind;
            return p;
        }

        public void ShowPlay()
        {
            Begin(Page.Play);
            var look=Rect("Drag to look",page);
            look.anchorMin=new Vector2(.43f,0); look.anchorMax=Vector2.one;
            look.offsetMin=look.offsetMax=Vector2.zero;
            Fill(look,Color.clear,true); Pad(look,TouchPad.Kind.Look);

            var stick=Box(page,"Move",BottomLeft,85,82,126,126);
            Fill(stick,Glass,true).sprite=circle;
            var knob=Box(stick,"Thumb",Center,0,0,53,53); Fill(knob,Paper).sprite=circle;
            Pad(stick,TouchPad.Kind.Move).Knob=knob;
            var fire=Box(page,"Pulse",BottomRight,-78,76,101,101);
            Fill(fire,Amber,true).sprite=circle;
            Pad(fire,TouchPad.Kind.Fire); Label(fire,"PULSE",19,Ink);
            charge=Label(Box(page,"Charge",BottomRight,-78,142,155,25),"",16,Paper);
            var strip=Box(page,"Round",Top,0,-35,254,49);
            Fill(strip,Ink);
            timer=Label(Box(strip,"Clock",Center,-62,0,102,44),"",23,Paper);
            score=Label(Box(strip,"Score",Center,57,0,112,44),"",23,Amber);
            Button(page,"II",TopRight,-40,-35,58,48,game.Pause);
            // The aiming point uses the camera viewport center even on asymmetrical cutouts.
            reticle=Box(canvasRect,"Aim",Center,0,0,115,95);
            dot=Fill(Box(reticle,"Point",Center,0,0,6,6),Paper); dot.sprite=circle;
            flash=Label(Box(reticle,"Hit",Center,44,21,88,30),"+100",21,Amber);
            oldSeconds=oldScore=oldCharge=oldRechargeStep=-1;
            oldFlash=true; oldOnPlate=!game.OnPlate;
            flash.enabled=true;
            Refresh();
        }

        public void Refresh()
        {
            if (current!=Page.Play) return;
            int seconds=Mathf.CeilToInt(game.Round.Remaining);
            if (oldSeconds!=seconds) { oldSeconds=seconds; timer.text="00:"+seconds.ToString("00"); }
            if (oldScore!=game.Round.Score) { oldScore=game.Round.Score; score.text=oldScore.ToString("0000"); }
            int step=Mathf.CeilToInt(game.Recharge*10);
            if (oldCharge!=game.Charges || oldRechargeStep!=step)
            {
                oldCharge=game.Charges; oldRechargeStep=step;
                charge.text=step>0 ? "CHARGE  "+(step/10f).ToString("0.0") : oldCharge+" / "+RangeGame.Capacity;
            }
            bool show=game.HitFlash>0;
            if (show!=oldFlash) { oldFlash=show; flash.enabled=show; }
            if (game.OnPlate!=oldOnPlate) { oldOnPlate=game.OnPlate; dot.color=oldOnPlate?Mint:Paper; }
        }

        public void ShowPause()
        {
            Begin(Page.Pause);
            var card=Card("TIME ATTACK","PAUSED");
            Row(card,"RESUME",28,game.Resume,true);
            Row(card,"SETTINGS",-36,()=>Settings(true));
            Row(card,"HOME",-145,game.Home);
        }

        public void ShowResult()
        {
            Begin(Page.Result);
            var card=Card("DEPOT   /   TIME ATTACK","RUN COMPLETE");
            Line(card,"Score      "+game.Round.Score,27,Amber,0,47,300,42);
            Line(card,"Hits   "+game.Round.Hits+" / "+game.Round.Shots+"     ·     "+game.Round.Accuracy+"%",19,Paper,0,4,300,35);
            Row(card,"RETRY",-82,game.StartRun,true);
            Row(card,"HOME",-145,game.Home);
        }

        public void Back()
        {
            switch(current)
            {
                case Page.Play: game.Pause(); break;
                case Page.Pause: game.Resume(); break;
                case Page.Settings: if (pausedSettings) ShowPause(); else ShowHome(); break;
                case Page.Result: game.Home(); break;
                case Page.Home: break;
                default: ShowHome(); break;
            }
        }

        void OnDestroy()
        {
            if(circle) Destroy(circle);
            if(circlePixels) Destroy(circlePixels);
        }
    }
}
