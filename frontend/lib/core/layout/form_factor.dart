import 'package:flutter/material.dart';

/// Responsive form factors based on layout width breakpoints:
/// - compact: < 600dp (Android phone in portrait, one-handed reachability)
/// - medium: 600 - 839dp (Large phone / small tablet portrait / foldables)
/// - expanded: >= 840dp (Tablet landscape, desktop)
enum FormFactor {
  compact,
  medium,
  expanded;

  bool get isCompact => this == FormFactor.compact;
  bool get isMedium => this == FormFactor.medium;
  bool get isExpanded => this == FormFactor.expanded;
  bool get isHandheld => this == FormFactor.compact || this == FormFactor.medium;
}

FormFactor formFactorOf(double width) {
  if (width < 600) {
    return FormFactor.compact;
  }
  if (width < 840) {
    return FormFactor.medium;
  }
  return FormFactor.expanded;
}

extension FormFactorExtension on BuildContext {
  FormFactor get formFactor {
    final width = MediaQuery.sizeOf(this).width;
    return formFactorOf(width);
  }

  bool get isCompact => formFactor.isCompact;
  bool get isMedium => formFactor.isMedium;
  bool get isExpanded => formFactor.isExpanded;
  bool get isHandheld => formFactor.isHandheld;
}
