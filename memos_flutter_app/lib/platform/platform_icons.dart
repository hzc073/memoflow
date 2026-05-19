import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class PlatformIcons {
  const PlatformIcons._();

  static IconData get back => CupertinoIcons.back;
  static IconData get close => CupertinoIcons.xmark;
  static IconData get more => CupertinoIcons.ellipsis;
  static IconData get share => CupertinoIcons.share;
  static IconData get add => CupertinoIcons.add;
  static IconData get edit => CupertinoIcons.pencil;
  static IconData get delete => CupertinoIcons.trash;
  static IconData get settings => CupertinoIcons.settings;
  static IconData get search => CupertinoIcons.search;
  static IconData get notifications => CupertinoIcons.bell;
  static IconData get sidebar => CupertinoIcons.sidebar_left;
  static IconData get check => CupertinoIcons.check_mark;
  static IconData get warning => CupertinoIcons.exclamationmark_triangle;
  static IconData get destructive => CupertinoIcons.exclamationmark_octagon;
  static IconData get cancel => CupertinoIcons.clear;
  static IconData get chevronForward => CupertinoIcons.chevron_forward;

  static IconData get platformBack => Icons.arrow_back_ios_new_rounded;
  static IconData get platformClose => Icons.close_rounded;
}
