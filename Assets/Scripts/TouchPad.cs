using UnityEngine;
using UnityEngine.EventSystems;

namespace VectorRange
{
    public sealed class TouchPad : MonoBehaviour, IPointerDownHandler, IDragHandler, IPointerUpHandler
    {
        public enum Kind { Move, Look, Fire }
        public Kind Mode;
        public RangeGame Game;
        public RectTransform Knob;
        int? owner;

        public void OnPointerDown(PointerEventData e)
        {
            if (owner.HasValue || e.button != PointerEventData.InputButton.Left) return;
            owner = e.pointerId;
            if (Mode == Kind.Fire) Game.Fire();
            if (Mode == Kind.Move) Move(e);
        }

        public void OnDrag(PointerEventData e)
        {
            if (owner != e.pointerId) return;
            if (Mode == Kind.Move) Move(e);
            else Game.Look(e.delta);
        }

        void Move(PointerEventData e)
        {
            var area = (RectTransform)transform;
            if (!RectTransformUtility.ScreenPointToLocalPointInRectangle(area,e.position,e.pressEventCamera,out var point)) return;
            var radius = area.rect.width * 0.34f;
            Game.Stick = Vector2.ClampMagnitude((point-area.rect.center)/radius,1);
            Knob.anchoredPosition = Game.Stick * radius;
        }

        public void OnPointerUp(PointerEventData e)
        {
            if (owner == e.pointerId) Release();
        }

        void OnDisable() => Release();

        void Release()
        {
            owner = null;
            if (Mode != Kind.Move || !Game) return;
            Game.Stick = Vector2.zero;
            if (Knob) Knob.anchoredPosition = Vector2.zero;
        }
    }
}
