"""Builds the human-readable reasoning shown on the Alert Detail screen.

The explanation is derived entirely from the Risk Engine breakdown — no LLM
call is involved.  Each sub-score that materially contributed becomes one
clause, so the beekeeper can see *why* the system escalated, not just that it
did.
"""

from __future__ import annotations

from app.config import Settings
from app.enums import AlertSeverity
from app.services.risk_engine import RiskBreakdown

#: A sub-score below this did not meaningfully drive the decision.
_CONTRIBUTION_FLOOR = 20.0


def build_message(hive_name: str, severity: AlertSeverity) -> str:
    """The short line used as the push notification body and list summary."""
    if severity is AlertSeverity.DANGER:
        return f"{hive_name}에서 말벌 집단 공격 징후가 감지되었습니다."
    return f"{hive_name}에서 말벌 활동이 증가하고 있습니다."


def build_explanation(
    breakdown: RiskBreakdown,
    settings: Settings,
    severity: AlertSeverity,
) -> str:
    """Compose the full reasoning paragraph from the score breakdown."""
    window = int(settings.risk_window_seconds)
    reasons: list[str] = []

    if breakdown.visual_count_score >= _CONTRIBUTION_FLOOR:
        reasons.append(
            f"현재 말벌 {breakdown.current_hornet_count}마리가 탐지되었고 "
            f"최근 {window}초 내 최대 {breakdown.recent_max_hornet_count}마리까지 관측되었습니다"
        )

    if breakdown.persistence_score >= _CONTRIBUTION_FLOOR:
        percent = int(round(breakdown.persistence_ratio * 100))
        reasons.append(
            f"최근 분석 프레임의 {percent}%에서 말벌이 연속적으로 확인되어 "
            "일시적인 통과가 아닌 지속적인 체류로 판단됩니다"
        )

    if breakdown.growth_score >= _CONTRIBUTION_FLOOR:
        reasons.append(
            f"말벌 개체 수가 초당 약 {breakdown.growth_per_second:.2f}마리 속도로 "
            "빠르게 증가하고 있습니다"
        )

    if breakdown.audio_score >= _CONTRIBUTION_FLOOR:
        percent = int(round(breakdown.audio_probability * 100))
        reasons.append(
            f"음향 분석에서 말벌 관련 신호가 {percent}% 확률로 함께 감지되었습니다"
        )

    if not reasons:
        reasons.append(
            f"최근 {window}초 동안의 영상 및 음향 지표가 복합적으로 상승했습니다"
        )

    body = ", ".join(reasons)
    verdict = (
        "집단 공격 가능성이 높아 즉시 확인이 필요합니다."
        if severity is AlertSeverity.DANGER
        else "상황을 주의 깊게 관찰할 필요가 있습니다."
    )
    return f"{body}. {verdict}"


def build_status_reason(breakdown: RiskBreakdown, settings: Settings) -> str:
    """A one-line reason attached to every hive status response."""
    if breakdown.frames_considered == 0:
        return "최근 분석된 프레임이 없습니다."
    if breakdown.current_hornet_count == 0 and breakdown.recent_max_hornet_count == 0:
        return f"최근 {int(settings.risk_window_seconds)}초 동안 말벌이 탐지되지 않았습니다."
    return (
        f"현재 {breakdown.current_hornet_count}마리 탐지, "
        f"최근 최대 {breakdown.recent_max_hornet_count}마리, "
        f"음향 위험도 {int(round(breakdown.audio_probability * 100))}%."
    )
