import 'dart:ui';

import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/state.dart';
import 'package:flutter/material.dart';

import 'scaffold.dart';
import 'side_sheet.dart';
import 'text.dart';
import 'pop_scope.dart';

@immutable
class SheetProps {
  final double? maxWidth;
  final double? maxHeight;
  final bool isScrollControlled;
  final bool useSafeArea;
  final bool blur;
  final Color? barrierColor;

  const SheetProps({
    this.maxWidth,
    this.maxHeight,
    this.useSafeArea = true,
    this.isScrollControlled = false,
    this.blur = true,
    this.barrierColor,
  });
}

@immutable
class ExtendProps {
  final double? maxWidth;
  final bool useSafeArea;
  final bool blur;
  final bool forceFull;

  const ExtendProps({
    this.maxWidth,
    this.useSafeArea = true,
    this.blur = true,
    this.forceFull = false,
  });
}

enum SheetType { page, bottomSheet, sideSheet }

typedef SheetBuilder = Widget Function(BuildContext context, SheetType type);

class _BlurModalBottomSheetRoute<T> extends ModalBottomSheetRoute<T> {
  final ImageFilter? _filter;

  _BlurModalBottomSheetRoute({
    required super.builder,
    super.capturedThemes,
    super.barrierLabel,
    super.barrierOnTapHint,
    super.backgroundColor,
    super.elevation,
    super.shape,
    super.clipBehavior,
    super.constraints,
    super.modalBarrierColor,
    super.isDismissible = true,
    super.enableDrag = true,
    super.showDragHandle,
    required super.isScrollControlled,
    super.scrollControlDisabledMaxHeightRatio = 9.0 / 16.0,
    super.settings,
    super.transitionAnimationController,
    super.anchorPoint,
    super.useSafeArea = false,
    super.sheetAnimationStyle,
    ImageFilter? filter,
  }) : _filter = filter;

  @override
  Widget buildModalBarrier() {
    final Widget barrier = barrierColor.a != 0 && !offstage
        ? AnimatedModalBarrier(
            color: animation!.drive(
              ColorTween(
                begin: barrierColor.withValues(alpha: 0.0),
                end: barrierColor,
              ).chain(CurveTween(curve: barrierCurve)),
            ),
            dismissible: barrierDismissible,
            semanticsLabel: barrierLabel,
            barrierSemanticsDismissible: semanticsDismissible,
            semanticsOnTapHint: barrierOnTapHint,
          )
        : ModalBarrier(
            dismissible: barrierDismissible,
            semanticsLabel: barrierLabel,
            barrierSemanticsDismissible: semanticsDismissible,
            semanticsOnTapHint: barrierOnTapHint,
          );
    final blurFilter = _filter;
    if (blurFilter == null) {
      return barrier;
    }
    // 模糊层随动画淡入（恒定子树，压暗层在其上），与系统弹窗背景虚化同款过渡
    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.topLeft,
      clipBehavior: Clip.none,
      children: [
        FadeTransition(
          opacity: animation!.drive(CurveTween(curve: barrierCurve)),
          child: BackdropFilter(
            filter: blurFilter,
            child: const SizedBox.expand(),
          ),
        ),
        barrier,
      ],
    );
  }
}

Future<T?> showSheet<T>({
  required BuildContext context,
  required SheetBuilder builder,
  SheetProps props = const SheetProps(),
}) {
  final isMobile = globalState.appState.viewMode == ViewMode.mobile;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final defaultBarrierColor =
      isDark ? const Color(0x66000000) : const Color(0x33000000);
  return switch (isMobile) {
    true => () {
        final navigator = Navigator.of(context);
        final localizations = MaterialLocalizations.of(context);
        return navigator.push<T>(
          _BlurModalBottomSheetRoute<T>(
            builder: (_) => builder(context, SheetType.bottomSheet),
            capturedThemes:
                InheritedTheme.capture(from: context, to: navigator.context),
            isScrollControlled: props.isScrollControlled,
            barrierLabel: localizations.scrimLabel,
            barrierOnTapHint:
                localizations.scrimOnTapHint(localizations.bottomSheetLabel),
            backgroundColor: Colors.transparent,
            elevation: 0,
            modalBarrierColor: props.barrierColor ?? defaultBarrierColor,
            showDragHandle: false,
            useSafeArea: props.useSafeArea,
            filter: resolveSheetFilter(
              context,
              props.blur ? commonFilter : null,
            ),
          ),
        );
      }(),
    false => showModalSideSheet<T>(
        useSafeArea: props.useSafeArea,
        isScrollControlled: props.isScrollControlled,
        barrierColor: props.barrierColor ?? defaultBarrierColor,
        context: context,
        constraints: BoxConstraints(maxWidth: props.maxWidth ?? 360),
        filter: props.blur ? commonFilter : null,
        builder: (_) {
          return builder(context, SheetType.sideSheet);
        },
      ),
  };
}

Future<T?> showExtend<T>(
  BuildContext context, {
  required SheetBuilder builder,
  ExtendProps props = const ExtendProps(),
}) {
  final isMobile = globalState.appState.viewMode == ViewMode.mobile;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final defaultBarrierColor =
      isDark ? const Color(0x66000000) : const Color(0x33000000);
  return switch (isMobile || props.forceFull) {
    true => BaseNavigator.push(context, builder(context, SheetType.page)),
    false => showModalSideSheet<T>(
        useSafeArea: props.useSafeArea,
        barrierColor: defaultBarrierColor,
        context: context,
        constraints: BoxConstraints(maxWidth: props.maxWidth ?? 360),
        filter: props.blur ? commonFilter : null,
        builder: (context) {
          return builder(context, SheetType.sideSheet);
        },
      ),
  };
}

class AdaptiveSheetScaffold extends StatelessWidget {
  final SheetType type;
  final Widget body;
  final String title;
  final List<Widget> actions;
  final Widget? leading;
  final bool? showScrollGradient;

  const AdaptiveSheetScaffold({
    super.key,
    required this.type,
    required this.body,
    required this.title,
    this.actions = const [],
    this.leading,
    this.showScrollGradient,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = context.colorScheme.surface;
    final bottomSheet = type == SheetType.bottomSheet;
    final sideSheet = type == SheetType.sideSheet;
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final implyLeading = !bottomSheet && (!(actions.isEmpty && sideSheet));
    final hasLeading = leading != null || (implyLeading && canPop);
    final effectiveLeading =
        leading ?? (implyLeading && canPop ? const BackButton() : null);
    final appBar = AppBar(
      leading: effectiveLeading != null
          ? Padding(
              padding: const EdgeInsets.only(left: 2.0),
              child: Center(
                child: effectiveLeading,
              ),
            )
          : null,
      leadingWidth: hasLeading ? 58.0 : null,
      forceMaterialTransparency: bottomSheet ? true : false,
      automaticallyImplyLeading: false,
      titleSpacing: hasLeading ? 0.0 : (bottomSheet ? null : 18.0),
      centerTitle: bottomSheet,
      backgroundColor: backgroundColor,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0.0,
      title: EmojiText(
        title,
      ),
      actions: genActions([
        if (actions.isEmpty && sideSheet) const CloseButton(),
        ...actions,
      ]),
    );
    final content = bottomSheet
        ? Material(
            color: backgroundColor,
            clipBehavior: Clip.antiAlias,
            shape: const RoundedSuperellipseBorder(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(35.0),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Container(
                      alignment: Alignment.center,
                      height: 4,
                      width: 32,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  appBar,
                  Flexible(
                    flex: 1,
                    child: (showScrollGradient ?? true)
                        ? ScrollConfiguration(
                            behavior: const FeatherBarScrollBehavior(),
                            child: body,
                          )
                        : body,
                  ),
                ],
              ),
            ),
          )
        : CommonScaffold(
            appBar: appBar,
            backgroundColor: backgroundColor,
            body: body,
            showScrollGradient: showScrollGradient,
          );

    final isTv = globalState.isAndroidTV;
    return PopScope(
      canPop: !isTv,
      onPopInvokedWithResult: !isTv
          ? null
          : (didPop, result) {
              if (didPop) return;
              if (dismissTvInputFocus()) return;
              if (ModalRoute.of(context)?.isCurrent != true) return;
              Navigator.of(context).pop();
            },
      child: content,
    );
  }
}
