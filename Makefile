LOCAL_PATH		:= $(shell pwd)

UNAME_SYSTEM	:= $(shell uname -s)
UNAME_ARCH		:= $(shell uname -r)

OS_NAME			:= linux-x86_64

APP_NAME		?= test_app
LABEL			:= $(APP_NAME)
APK_FILE		:= $(APP_NAME).apk
PACKAGE_NAME	:= org.specialist.$(APP_NAME)

ANDROID_VERSION	?= 30
ANDROID_TARGET	:= $(ANDROID_VERSION)

ANDROID_SDK			:= $(ANDROID_HOME)
ANDROID_NDK			:= $(ANDROID_NDK_HOME)
ANDROID_BUILD_TOOLS	:= $(ANDROID_HOME)/build-tools/35.0.0

KEYSTORE_TYPE		:= test
KEYSTORE_PATH		:= $(LOCAL_PATH)/.keystore
KEYSTORE_FILE		:= $(KEYSTORE_PATH)/$(KEYSTORE_TYPE)-key.keystore
KEYSTORE_DNAME		:= "CN=none, OU=ID, O=Specialist, L=Specialist, S=Specialist, C=GB"
KEYSTORE_PASS		:= testapp_pass


CC		:= $(ANDROID_NDK)/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android$(ANDROID_VERSION)-clang

AAPT		:= $(ANDROID_BUILD_TOOLS)/aapt
ZIPALIGN	:= $(ANDROID_BUILD_TOOLS)/zipalign
APKSIGNER	:= $(ANDROID_BUILD_TOOLS)/apksigner


CFLAGS			:= \
	-Os \
	-Wall \
	-Wextra \
	-fPIC \
	-m64 \
	-ffunction-sections \
	-fdata-sections \
	-fvisibility=hidden \
	-DANDROID \
	-DAPPNAME=\"$(APP_NAME)\" \
	-DANDROIDVERSION=$(ANDROID_VERSION) \
	-I$(ANDROID_NDK)/sysroot/usr/include \
	-I$(ANDROID_NDK)/sysroot/usr/include/android \
	-I$(ANDROID_NDK)/toolchains/llvm/prebuilt/$(OS_NAME)/sysroot/usr/include \
	-I$(ANDROID_NDK)/toolchains/llvm/prebuilt/$(OS_NAME)/sysroot/usr/include/android

LDFLAGS			:= \
	-s \
	-Wl,--gc-sections \
	-Wl,-Map=$(APP_NAME).map \
	-lm \
	-lGLESv3 \
	-lEGL \
	-landroid \
	-llog \
	-lOpenSLES \
	-shared \
	-uANativeActivity_onCreate

TARGETS			:= \
	$(APP_NAME)/lib/arm64-v8a/lib$(APP_NAME).so

ANDROID_SRC		:= \
	$(LOCAL_PATH)/src/main.c





.PHONY: all
app: clean create_dirs manifest $(APK_FILE)




$(APK_FILE): $(TARGETS)
	@rm -f *.apk
	@mkdir -p $(APP_NAME)/assets/res/values
	@cp -Rf $(LOCAL_PATH)/sources/assets/ $(APP_NAME)/

	@APP_NAME=$(APP_NAME) PACKAGE_NAME=$(PACKAGE_NAME) envsubst '$$APP_NAME $$PACKAGE_NAME' < $(LOCAL_PATH)/sources/res/values/strings.xml.in > $(LOCAL_PATH)/$(APP_NAME)/assets/res/values/strings.xml

	@$(AAPT) package -f -F tmp.apk -I $(ANDROID_SDK)/platforms/android-$(ANDROID_VERSION)/android.jar -M $(LOCAL_PATH)/AndroidManifest.xml -S $(LOCAL_PATH)/sources/res -A $(APP_NAME)/assets -v --target-sdk-version $(ANDROID_VERSION)

	@unzip -o tmp.apk -d $(APP_NAME)
	@rm -f tmp2.apk

	@cd $(APP_NAME) && zip -D4r ../tmp2.apk . && zip -D0r ../tmp2.apk resources.arsc AndroidManifest.xml

	@$(ZIPALIGN) -v 4 tmp2.apk $(APK_FILE)
	@$(APKSIGNER) sign --key-pass pass:$(KEYSTORE_PASS) --ks-pass pass:$(KEYSTORE_PASS) --ks $(KEYSTORE_FILE) $(APK_FILE)
	@rm -f tmp*.apk



$(APP_NAME)/lib/arm64-v8a/lib$(APP_NAME).so: $(ANDROID_SRC)
	@mkdir -p $(APP_NAME)/lib/arm64-v8a
	@$(CC) $(CFLAGS) -o $@ $^ -L$(ANDROID_NDK)/toolchains/llvm/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/$(ANDROID_VERSION) $(LDFLAGS)

manifest:
	@rm -f AndroidManifest.xml
	@PACKAGE_NAME=$(PACKAGE_NAME) \
	ANDROID_VERSION=$(ANDROID_VERSION) \
	ANDROID_TARGET=$(ANDROID_TARGET) \
	APP_NAME=$(APP_NAME) \
	LABEL=$(LABEL) \
	envsubst '$$ANDROID_TARGET $$ANDROID_VERSION $$APP_NAME $$PACKAGE_NAME $$LABEL' \
	< $(LOCAL_PATH)/manifests/AndroidManifest.xml.in > AndroidManifest.xml



keystore:
	@mkdir -p $(KEYSTORE_PATH)
	@keytool -genkey -v -keystore $(KEYSTORE_FILE) -keyalg RSA -keysize 2048 -validity 10000 -storepass $(KEYSTORE_PASS) -keypass $(KEYSTORE_PASS) -dname $(KEYSTORE_DNAME)


create_dirs:
	@mkdir -p $(APP_NAME)/lib/arm64-v8a

clean:
	@rm -rf *.map *.idsig *.apk media/ $(APP_NAME)/