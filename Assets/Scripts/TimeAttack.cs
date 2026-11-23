using System;

namespace VectorRange
{
    public enum RoundState { Home, Running, Paused, Finished }

    public sealed class TimeAttack
    {
        public const float Duration = 30f;
        public const int HitValue = 100;
        public RoundState State { get; private set; } = RoundState.Home;
        public float Remaining { get; private set; }
        public int Shots { get; private set; }
        public int Hits { get; private set; }
        public int Score => Hits * HitValue;
        public int Accuracy => Shots == 0 ? 0 : (int)Math.Round(100.0 * Hits / Shots);

        public void Start()
        {
            Remaining = Duration;
            Hits = Shots = 0;
            State = RoundState.Running;
        }

        public void Tick(float elapsed)
        {
            if (State != RoundState.Running) return;
            Remaining = Math.Max(0f, Remaining - Math.Max(0f, elapsed));
            if (Remaining == 0f) State = RoundState.Finished;
        }

        public void Shoot(bool hit)
        {
            if (State != RoundState.Running) return;
            Shots++;
            if (hit) Hits++;
        }

        public void Pause() { if (State == RoundState.Running) State = RoundState.Paused; }
        public void Resume() { if (State == RoundState.Paused) State = RoundState.Running; }
        public void Home() { State = RoundState.Home; }
    }
}
