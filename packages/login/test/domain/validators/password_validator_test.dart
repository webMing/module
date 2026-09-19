import 'package:flutter_test/flutter_test.dart';
import 'package:login/login.dart';

void main() {
  group('PasswordValidator.validateForLogin', () {
    test('空密码给出提示', () {
      expect(PasswordValidator.validateForLogin(null), '请输入密码');
      expect(PasswordValidator.validateForLogin(''), '请输入密码');
    });

    test('长度不能超过 30 位', () {
      expect(PasswordValidator.validateForLogin('a' * 30), isNull);
      expect(PasswordValidator.validateForLogin('a' * 31), '密码长度不能超过 30 位');
    });

    test('只能包含字母和数字', () {
      expect(PasswordValidator.validateForLogin('abc123!'), '密码只能包含字母和数字');
      expect(PasswordValidator.validateForLogin('密码123'), '密码只能包含字母和数字');
      expect(PasswordValidator.validateForLogin('abc 123'), '密码只能包含字母和数字');
    });

    test('登录不强制最短长度与字母数字混合', () {
      expect(PasswordValidator.validateForLogin('abc123'), isNull);
      expect(PasswordValidator.validateForLogin('123456'), isNull);
      expect(PasswordValidator.validateForLogin('abcdef'), isNull);
      expect(PasswordValidator.validateForLogin('a'), isNull);
    });
  });

  group('PasswordValidator.validateForNewPassword', () {
    test('空密码给出提示', () {
      expect(PasswordValidator.validateForNewPassword(null), '请输入新密码');
      expect(PasswordValidator.validateForNewPassword(''), '请输入新密码');
    });

    test('长度必须为 6-30 位', () {
      expect(
        PasswordValidator.validateForNewPassword('abc12'),
        '密码长度需为 6-30 位',
      );
      expect(
        PasswordValidator.validateForNewPassword('a1${'a' * 29}'),
        '密码长度需为 6-30 位',
      );
      expect(PasswordValidator.validateForNewPassword('abc123'), isNull);
      expect(PasswordValidator.validateForNewPassword('a1${'a' * 28}'), isNull);
    });

    test('必须同时包含字母和数字', () {
      expect(
        PasswordValidator.validateForNewPassword('abcdef'),
        '密码必须同时包含字母和数字',
      );
      expect(
        PasswordValidator.validateForNewPassword('123456'),
        '密码必须同时包含字母和数字',
      );
    });

    test('只能包含字母和数字', () {
      expect(
        PasswordValidator.validateForNewPassword('abc 123'),
        '密码只能包含字母和数字',
      );
      expect(
        PasswordValidator.validateForNewPassword('abc123!'),
        '密码只能包含字母和数字',
      );
    });
  });

  group('PasswordValidator.validateConfirmation', () {
    test('确认密码为空', () {
      expect(
        PasswordValidator.validateConfirmation(
          password: 'abc123',
          confirmation: '',
        ),
        '请再次输入密码',
      );
    });

    test('两次输入不一致', () {
      expect(
        PasswordValidator.validateConfirmation(
          password: 'abc123',
          confirmation: 'abc124',
        ),
        '两次输入的密码不一致',
      );
    });

    test('两次输入一致', () {
      expect(
        PasswordValidator.validateConfirmation(
          password: 'abc123',
          confirmation: 'abc123',
        ),
        isNull,
      );
    });
  });
}
