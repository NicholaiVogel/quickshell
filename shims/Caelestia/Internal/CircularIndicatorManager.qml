import QtQuick

QtObject {
    id: root

    // output properties
    property real startFraction: 0
    property real endFraction: 0
    property real rotation: 0

    // writable inputs
    property real progress: 0
    property real completeEndProgress: 0

    // readonly computed durations
    readonly property real duration: {
        if (indeterminateAnimationType === 0) return 5400;
        return 6000;
    }
    readonly property real completeEndDuration: {
        if (indeterminateAnimationType === 0) return 333;
        return 500;
    }

    // 0 = Advance, 1 = Retreat
    property int indeterminateAnimationType: 0

    onProgressChanged: _update()
    onCompleteEndProgressChanged: _update()
    onIndeterminateAnimationTypeChanged: _update()

    // -- cubic bezier easing: (0.4, 0.0), (0.2, 1.0) --
    // fast out slow in (MD3)

    function _cubicBezierY(t) {
        // control points: P0=(0,0) P1=(0.4,0) P2=(0.2,1) P3=(1,1)
        var u = 1 - t;
        // y = 3*u^2*t*P1y + 3*u*t^2*P2y + t^3*P3y
        // P1y=0, P2y=1, P3y=1
        return 3 * u * t * t * 1.0 + t * t * t * 1.0;
    }

    function _solveBezierX(x) {
        // P1x=0.4, P2x=0.2, P3x=1
        // newton-raphson to find t for given x
        var t = x;
        for (var i = 0; i < 8; i++) {
            var u = 1 - t;
            var cx = 3 * u * u * t * 0.4
                   + 3 * u * t * t * 0.2
                   + t * t * t * 1.0;
            var dx = cx - x;
            if (Math.abs(dx) < 1e-7) break;
            // derivative of x bezier w.r.t. t
            var dxdt = 3 * (1 - t) * (1 - t) * 0.4
                     + 6 * (1 - t) * t * (0.2 - 0.4)
                     + 3 * t * t * (1.0 - 0.2);
            if (Math.abs(dxdt) < 1e-7) break;
            t -= dx / dxdt;
            t = Math.max(0, Math.min(1, t));
        }
        return t;
    }

    function _ease(x) {
        if (x <= 0) return 0;
        if (x >= 1) return 1;
        return _cubicBezierY(_solveBezierX(x));
    }

    function _clamp(v, lo, hi) {
        return Math.max(lo, Math.min(hi, v));
    }

    function _getFractionInRange(playtime, start, dur) {
        return _clamp((playtime - start) / dur, 0, 1);
    }

    function _lerp(a, b, t) {
        return a + (b - a) * t;
    }

    // -- advance mode constants --
    readonly property var _advExpandDelay: [0, 1350, 2700, 4050]
    readonly property var _advCollapseDelay: [667, 2017, 3367, 4717]
    readonly property real _advTotalDuration: 5400
    readonly property real _advExpandDuration: 667
    readonly property real _advCollapseDuration: 667
    readonly property real _advTailOffset: -20
    readonly property real _advExtraPerCycle: 250
    readonly property real _advConstantRotation: 1520

    // -- retreat mode constants --
    readonly property real _retTotalDuration: 6000
    readonly property real _retSpinDuration: 500
    readonly property real _retGrowActiveDuration: 3000
    readonly property real _retShrinkActiveDuration: 3000
    readonly property var _retDelaySpins: [0, 1500, 3000, 4500]
    readonly property real _retDelayGrow: 0
    readonly property real _retDelayShrink: 3000
    readonly property real _retConstantRotation: 1080
    readonly property real _retSpinRotation: 90
    readonly property real _retEndFracLo: 0.10
    readonly property real _retEndFracHi: 0.87

    function _update() {
        if (indeterminateAnimationType === 0) {
            _updateAdvance(progress);
        } else {
            _updateRetreat(progress);
        }
    }

    function _updateAdvance(p) {
        var playtime = p * _advTotalDuration;
        var sf = _advConstantRotation * p + _advTailOffset;
        var ef = _advConstantRotation * p;

        for (var i = 0; i < 4; i++) {
            ef += _ease(
                _getFractionInRange(
                    playtime,
                    _advExpandDelay[i],
                    _advExpandDuration
                )
            ) * _advExtraPerCycle;
        }

        for (var j = 0; j < 4; j++) {
            sf += _ease(
                _getFractionInRange(
                    playtime,
                    _advCollapseDelay[j],
                    _advCollapseDuration
                )
            ) * _advExtraPerCycle;
        }

        // complete-end interpolation
        sf += (ef - sf) * completeEndProgress;

        root.startFraction = sf / 360;
        root.endFraction = ef / 360;
        root.rotation = 0;
    }

    function _updateRetreat(p) {
        var playtime = p * _retTotalDuration;

        var rot = _retConstantRotation * p;
        for (var i = 0; i < 4; i++) {
            rot += _ease(
                _getFractionInRange(
                    playtime,
                    _retDelaySpins[i],
                    _retSpinDuration
                )
            ) * _retSpinRotation;
        }

        var fraction = _ease(
            _getFractionInRange(
                playtime,
                _retDelayGrow,
                _retGrowActiveDuration
            )
        ) - _ease(
            _getFractionInRange(
                playtime,
                _retDelayShrink,
                _retShrinkActiveDuration
            )
        );

        root.rotation = rot;
        root.startFraction = 0;
        root.endFraction = _lerp(
            _retEndFracLo,
            _retEndFracHi,
            fraction
        ) * (1 - completeEndProgress);
    }
}
