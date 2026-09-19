import 'package:feature_auth/src/domain/services/account_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccountValidator.detectKind', () {
    test('含 @ 视为邮箱', () {
      expect(
        AccountValidator.detectKind('user@example.com'),
        AccountKind.email,
      );
    });

    test('纯数字视为手机号', () {
      expect(AccountValidator.detectKind('13800138000'), AccountKind.phone);
    });

    test('其余视为昵称', () {
      expect(AccountValidator.detectKind('张三'), AccountKind.nickname);
      expect(AccountValidator.detectKind('zhang_san'), AccountKind.nickname);
    });

    test('空串无法识别', () {
      expect(AccountValidator.detectKind(''), isNull);
      expect(AccountValidator.detectKind('   '), isNull);
    });
  });

  group('AccountValidator.validate', () {
    test('空账号给出提示', () {
      expect(AccountValidator.validate(null), '请输入账号');
      expect(AccountValidator.validate(''), '请输入账号');
      expect(AccountValidator.validate('   '), '请输入账号');
    });

    test('合法手机号通过（含首尾空格）', () {
      expect(AccountValidator.validate('13800138000'), isNull);
      expect(AccountValidator.validate(' 19912345678 '), isNull);
    });

    test('非法手机号被拦截', () {
      expect(AccountValidator.validate('12800138000'), '手机号格式不正确');
      expect(AccountValidator.validate('1380013800'), '手机号格式不正确');
      expect(AccountValidator.validate('138001380000'), '手机号格式不正确');
    });

    test('合法邮箱通过', () {
      expect(AccountValidator.validate('user@example.com'), isNull);
      expect(AccountValidator.validate('a.b-c+1@sub.example.co'), isNull);
    });

    test('非法邮箱被拦截', () {
      expect(AccountValidator.validate('user@'), '邮箱格式不正确');
      expect(AccountValidator.validate('user@example'), '邮箱格式不正确');
      expect(AccountValidator.validate('@example.com'), '邮箱格式不正确');
    });

    test('昵称长度不能超过 30 个字符', () {
      expect(AccountValidator.validate('a' * 30), isNull);
      expect(AccountValidator.validate('张' * 30), isNull);
      expect(AccountValidator.validate('a' * 31), '昵称长度不能超过 30 个字符');
      expect(AccountValidator.validate('张' * 31), '昵称长度不能超过 30 个字符');
    });
  });
}
