import 'package:bett_box/common/common.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/config.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/views/profiles/scripts.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

///
///
class ScriptOverride extends ConsumerWidget {
  const ScriptOverride({super.key});

  static String? _lastActiveScriptId;

  Future<void> _openScripts(BuildContext context) async {
    await showExtend(
      context,
      builder: (_, type) {
        return const ScriptsView();
      },
    );
  }

  Future<void> _handleToggle(WidgetRef ref, bool enable) async {
    final notifier = ref.read(scriptStateProvider.notifier);
    final props = ref.read(scriptStateProvider);
    final scripts = props.scripts;
    if (scripts.isEmpty) {
      return;
    }
    if (enable) {
      final remembered = _lastActiveScriptId;
      final index = scripts.indexWhere((item) => item.id == remembered);
      final target = index == -1 ? scripts.first : scripts[index];
      if (props.realId == target.id) {
        return;
      }
      notifier.setId(target.id);
      _lastActiveScriptId = target.id;
    } else {
      final currentId = props.currentId;
      if (currentId == null) {
        return;
      }
      _lastActiveScriptId = currentId;
      notifier.setId(currentId);
    }
    try {
      await globalState.appController.applyProfile(silence: true);
    } catch (e) {
      commonPrint.log('Apply profile after script override toggle failed: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scriptProps = ref.watch(scriptStateProvider);
    final isEnabled = scriptProps.realId != null;
    final hasScripts = scriptProps.scripts.isNotEmpty;

    return SizedBox(
      height: getWidgetHeight(1),
      child: CommonCard(
        info: Info(
          label: appLocalizations.script,
          iconData: FluentIcons.javascript_24_regular,
        ),
        onPressed: () {
          _openScripts(context);
        },
        child: Container(
          padding: baseInfoEdgeInsets.copyWith(top: 4, bottom: 8, right: 8),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                flex: 1,
                child: TooltipText(
                  text: Text(
                    appLocalizations.override,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.adjustSize(-2).toLight,
                  ),
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -3),
                child: Switch(
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  value: isEnabled,
                  onChanged: hasScripts
                      ? (value) {
                          _handleToggle(ref, value);
                        }
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
