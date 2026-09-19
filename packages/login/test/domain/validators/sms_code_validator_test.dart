import 'package:flutter_test/flutter_test.dart';
import 'package:login/login.dart';

void main() {
  group('SmsCodeValidator.validate', () {
    test('空验证码给出提示', () {
      expect(SmsCodeValidator.validate(null), '请输入短信验证码');
      expect(SmsCodeValidator.validate(''), '请输入短信验证码');
    });

    test('必须是 6 位数字', () {
      expect(SmsCodeValidator.validate('12345'), '短信验证码为 6 位数字');
      expect(SmsCodeValidator.validate('1234567'), '短信验证码为 6 位数字');
      expect(SmsCodeValidator.validate('12345a'), '短信验证码为 6 位数字');
    });

    test('6 位数字通过', () {
      expect(SmsCodeValidator.validate('123456'), isNull);
      expect(SmsCodeValidator.validate(' 000000 '), isNull);
    });

    test('位数为 6', () {
      expect(SmsCodeValidator.length, 6);
    });
  });
}
