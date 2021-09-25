import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'scroll_notification_publisher.dart';

// 控制曝光
class Exposure extends StatefulWidget {
  const Exposure({
    Key? key,
    required this.onExpose,
    required this.child,
  }) : super(key: key);

  final VoidCallback onExpose;
  final Widget child;

  @override
  State<Exposure> createState() => _ExposureState();
}

class _ExposureState extends State<Exposure> {
  bool show = false;
  ScrollState? state;

  @override
  void initState() {
    WidgetsBinding.instance?.addPostFrameCallback((timeStamp) {
      subScribeScrollNotification(context);
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  void subScribeScrollNotification(BuildContext context) {
    final StreamController<ScrollNotification> publisher =
        ScrollNotificationPublisher.of(context);
    publisher.stream.listen((scrollNotification) {
      trackWidgetPosition(
          scrollNotification.metrics.pixels, scrollNotification.metrics.axis);
    });
  }

  void trackWidgetPosition(double scrollOffset, Axis direction) {
    if (!mounted) {
      return;
    }
    final exposureOffset = getExposureOffset(context);
    final exposurePitSize = (context.findRenderObject() as RenderBox).size;
    final viewPortSize = getViewPortSize(context) ?? const Size(1, 1);
    if (direction == Axis.vertical) {
      checkExposure(exposureOffset, scrollOffset, exposurePitSize.height,
          viewPortSize.height);
    } else {
      checkExposure(exposureOffset, scrollOffset, exposurePitSize.width,
          viewPortSize.width);
    }
  }

  Size? getViewPortSize(BuildContext context) {
    final RenderObject? box = context.findRenderObject();
    final RenderAbstractViewport? viewport = RenderAbstractViewport.of(box);
    final Size? size = viewport?.paintBounds.size;
    return size;
  }

  double getExposureOffset(BuildContext context) {
    final RenderObject? box = context.findRenderObject();
    final RenderAbstractViewport? viewport = RenderAbstractViewport.of(box);

    if (viewport == null || box == null || !box.attached) {
      return 0.0;
    }

    final RevealedOffset offsetRevealToTop =
        viewport.getOffsetToReveal(box, 0.0, rect: Rect.zero);
    return offsetRevealToTop.offset;
  }

  void initScrollState(double exposureOffset, double scrollOffset,
      double currentSize, double viewPortSize) {
    bool scrollOutEnd = (exposureOffset - scrollOffset) > viewPortSize;
    bool scrollOutStart = (scrollOffset - exposureOffset) > currentSize;
    if (scrollOutEnd) {
      state = ScrollState.outOfViewPortEnd;
    }
    if (scrollOutStart) {
      state = ScrollState.outOfViewPortStart;
    }
    state ??= ScrollState.inViewPort;
  }

  void checkExposure(double exposureOffset, double scrollOffset,
      double currentSize, double viewPortSize) {
    if (state == null) {
      initScrollState(exposureOffset, scrollOffset, currentSize, viewPortSize);
    }
    if (!show && state == ScrollState.inViewPort) {
      show = true;
      widget.onExpose.call();
      return;
    }

    bool scrollInEnd =
        (exposureOffset + currentSize) < (scrollOffset + viewPortSize);
    bool scrollInStart = scrollOffset < exposureOffset;

    bool scrollOutEnd = (exposureOffset - scrollOffset) > viewPortSize;
    bool scrollOutStart = (scrollOffset - exposureOffset) > currentSize;

    if (state == ScrollState.outOfViewPortEnd) {
      if (scrollInEnd) {
        state = ScrollState.inViewPort;
        widget.onExpose.call();
        show = true;
        return;
      }
    }
    if (state == ScrollState.outOfViewPortStart) {
      if (scrollInStart) {
        state = ScrollState.inViewPort;
        widget.onExpose.call();
        show = true;
        return;
      }
    }
    if (state == ScrollState.inViewPort) {
      if (scrollOutStart) {
        state = ScrollState.outOfViewPortStart;
        return;
      }

      if (scrollOutEnd) {
        state = ScrollState.outOfViewPortEnd;
        return;
      }
    }
  }
}

enum ScrollState {
  outOfViewPortStart,
  inViewPort,
  outOfViewPortEnd,
}
