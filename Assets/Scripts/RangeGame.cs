using UnityEngine;
using UnityEngine.EventSystems;

namespace VectorRange
{
    public sealed class RangeGame : MonoBehaviour
    {
        public readonly TimeAttack Round = new TimeAttack();
        public Vector2 Stick { get; set; }
        public int Best { get; private set; }
        public int BestAccuracy { get; private set; }
        public bool Sound { get; private set; }
        public int Sensitivity { get; private set; }
        public int Charges { get; private set; }
        public const int Capacity = 5;
        const float RechargeSeconds = 1.05f;
        public float Recharge { get; private set; }
        public float HitFlash { get; private set; }
        public bool OnPlate { get; private set; }

        Camera eye;
        CharacterController body;
        Depot depot;
        RangeHud hud;
        AudioSource speaker;
        AudioClip hitTone, missTone;
        float yaw, pitch, recoil, bob;
        int litPlate = -1;

        void Awake()
        {
            Application.targetFrameRate = 60;
            Screen.orientation = ScreenOrientation.LandscapeLeft;
            Screen.sleepTimeout = SleepTimeout.NeverSleep;
            Best = PlayerPrefs.GetInt("range.best",0);
            BestAccuracy = PlayerPrefs.GetInt("range.bestAccuracy",0);
            Sound = PlayerPrefs.GetInt("range.sound",1) == 1;
            Sensitivity = Mathf.Clamp(PlayerPrefs.GetInt("range.sensitivity",1),0,2);
            depot = new Depot(transform);
            var player = new GameObject("Player");
            player.transform.SetParent(transform,false);
            body = player.AddComponent<CharacterController>();
            body.height = 1.72f;
            body.radius = 0.29f;
            body.center = Vector3.up * 0.86f;
            body.stepOffset = 0.20f;
            var cameraObject = new GameObject("Eyes",typeof(Camera),typeof(AudioListener));
            cameraObject.tag = "MainCamera";
            cameraObject.transform.SetParent(player.transform,false);
            cameraObject.transform.localPosition = Vector3.up * 1.49f;
            eye = cameraObject.GetComponent<Camera>();
            eye.nearClipPlane = 0.045f;
            eye.farClipPlane = 65f;
            eye.fieldOfView = 61;
            eye.clearFlags = CameraClearFlags.SolidColor;
            eye.backgroundColor = new Color(0.15f,0.21f,0.23f);
            depot.BuildViewModel(eye.transform);
            var events = new GameObject("Touch events",typeof(EventSystem),typeof(StandaloneInputModule));
            events.transform.SetParent(transform,false);
            speaker = cameraObject.AddComponent<AudioSource>();
            speaker.playOnAwake = false;
            hitTone = Tone(720,1050);
            missTone = Tone(210,140);
            hud = gameObject.AddComponent<RangeHud>();
            hud.Build(this);
            Home();
        }

        static AudioClip Tone(float start,float end)
        {
            const int rate = 22050, count = 1700;
            var samples = new float[count];
            float phase = 0;
            for (int i=0;i<count;i++)
            {
                float t = (float)i/(count-1);
                phase += 2*Mathf.PI*Mathf.Lerp(start,end,t)/rate;
                samples[i] = Mathf.Sin(phase)*Mathf.Min(t*25,1)*(1-t)*(1-t)*0.17f;
            }
            var clip = AudioClip.Create("Pulse tone",count,1,rate,false);
            clip.SetData(samples,0);
            return clip;
        }

        void Spawn(Vector3 floor,float heading)
        {
            body.enabled = false;
            body.transform.position = floor + Vector3.up * 0.035f;
            yaw = heading;
            pitch = 0;
            ApplyLook();
            body.enabled = true;
            Physics.SyncTransforms();
        }

        public void StartRun()
        {
            Round.Start();
            Spawn(new Vector3(0,0,-4.8f),0);
            ResetFeedback();
            Charges = Capacity;
            Recharge = recoil = bob = 0;
            Stick = Vector2.zero;
            depot.ViewModel.gameObject.SetActive(true);
            Pose();
            hud.ShowPlay();
            hud.Refresh();
        }

        public void Home()
        {
            Round.Home();
            ResetFeedback();
            Stick = Vector2.zero;
            Spawn(new Vector3(-5.5f,0,-6),19);
            depot.ViewModel.gameObject.SetActive(false);
            hud.ShowHome();
        }

        void Update()
        {
            if (Input.GetKeyDown(KeyCode.Escape))
            {
                hud.Back();
                return;
            }
            if (Round.State != RoundState.Running) return;
            float dt = Time.unscaledDeltaTime;
            Round.Tick(dt);
            if (Round.State == RoundState.Finished)
            {
                Best = Mathf.Max(Best,Round.Score);
                BestAccuracy = Mathf.Max(BestAccuracy,Round.Accuracy);
                PlayerPrefs.SetInt("range.best",Best);
                PlayerPrefs.SetInt("range.bestAccuracy",BestAccuracy);
                PlayerPrefs.Save();
                hud.ShowResult();
                return;
            }
            Vector2 move = Stick;
            if (Input.GetKey(KeyCode.A)) move.x--;
            if (Input.GetKey(KeyCode.D)) move.x++;
            if (Input.GetKey(KeyCode.W)) move.y++;
            if (Input.GetKey(KeyCode.S)) move.y--;
            move = Vector2.ClampMagnitude(move,1);
            var basis = body.transform;
            body.Move(((basis.right*move.x+basis.forward*move.y)*3.8f+Vector3.down*2)*Mathf.Min(dt,0.1f));
            if (Input.GetKeyDown(KeyCode.Space)) Fire();
            bob += dt*move.magnitude*8;
            recoil = Mathf.MoveTowards(recoil,0,dt*6);
            if (Recharge>0)
            {
                Recharge = Mathf.Max(0,Recharge-dt);
                if (Recharge==0) Charges=Capacity;
            }
            if (HitFlash>0)
            {
                HitFlash=Mathf.Max(0,HitFlash-dt);
                if (HitFlash==0) ResetFeedback();
            }
            OnPlate = AimedPlate()>=0;
            Pose();
            hud.Refresh();
        }

        void Pose()
        {
            float dip = Recharge>0 ? Mathf.Sin(Mathf.PI*Recharge/RechargeSeconds) : 0;
            depot.ViewModel.localPosition = new Vector3(0.22f,-0.16f-dip*0.15f+0.004f*Mathf.Sin(bob),0.39f-recoil*0.035f);
            depot.ViewModel.localRotation = Quaternion.Euler(-recoil*4+dip*18,-6,0);
        }

        public void Look(Vector2 delta)
        {
            if (Round.State!=RoundState.Running) return;
            float degrees = (62+Sensitivity*24)/(float)Mathf.Max(1,Screen.height);
            yaw += delta.x*degrees;
            pitch = Mathf.Clamp(pitch-delta.y*degrees,-65,68);
            ApplyLook();
        }

        void ApplyLook()
        {
            body.transform.rotation = Quaternion.Euler(0,yaw,0);
            eye.transform.localRotation = Quaternion.Euler(pitch,0,0);
        }

        int AimedPlate()
        {
            var ray = eye.ViewportPointToRay(new Vector3(0.5f,0.5f,0));
            return Physics.Raycast(ray,out var hit,50,Physics.DefaultRaycastLayers,QueryTriggerInteraction.Ignore)
                ? depot.Plates.IndexOf(hit.collider) : -1;
        }

        public void Fire()
        {
            if (Round.State!=RoundState.Running || Charges<=0) return;
            int index = AimedPlate();
            Round.Shoot(index>=0);
            Charges--;
            if (Charges==0) Recharge=RechargeSeconds;
            recoil=1;
            if (Sound) speaker.PlayOneShot(index>=0 ? hitTone : missTone);
            if (index>=0)
            {
                ResetFeedback();
                litPlate=index;
                depot.LightPlate(index,true);
                HitFlash=0.36f;
            }
            hud.Refresh();
        }

        void ResetFeedback()
        {
            if (litPlate>=0) depot.LightPlate(litPlate,false);
            litPlate=-1;
            HitFlash=0;
            OnPlate=false;
        }

        public void PreviewPulse(bool visible)
        {
            depot.ViewModel.gameObject.SetActive(visible);
            if (!visible) return;
            depot.ViewModel.localPosition = new Vector3(0.32f,-0.03f,0.82f);
            depot.ViewModel.localRotation = Quaternion.Euler(10,-70,-7);
        }

        public void Pause()
        {
            if (Round.State!=RoundState.Running) return;
            Round.Pause();
            Stick=Vector2.zero;
            hud.ShowPause();
        }

        public void Resume()
        {
            if (Round.State!=RoundState.Paused) return;
            Round.Resume();
            hud.ShowPlay();
        }

        public void ToggleSound()
        {
            Sound=!Sound;
            PlayerPrefs.SetInt("range.sound",Sound?1:0);
            PlayerPrefs.Save();
        }

        public void ChangeSensitivity()
        {
            Sensitivity=(Sensitivity+1)%3;
            PlayerPrefs.SetInt("range.sensitivity",Sensitivity);
            PlayerPrefs.Save();
        }

        void OnApplicationPause(bool value) { if (value && hud) Pause(); }
        void OnApplicationFocus(bool value) { if (!value && hud) Pause(); }
        void OnDestroy()
        {
            depot?.Dispose();
            if (hitTone) Destroy(hitTone);
            if (missTone) Destroy(missTone);
        }
    }
}
