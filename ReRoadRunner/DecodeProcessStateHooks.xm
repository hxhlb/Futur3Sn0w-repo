#import "RunningBoardServices.h"

static RBSProcessState *initProcessStateWithCoder(RBSProcessState *self, BSXPCCoder *coder) {
    self.partying = [coder decodeBoolForKey:kPartyingProcess];
    self.immortal = [coder decodeBoolForKey:kImmortalProcess];
    return self;
}

/* Transfer the binary data back to our properties. */
%hook RBSProcessState

%property (nonatomic, assign) BOOL partying;
%property (nonatomic, assign) BOOL immortal;

%end

%group RBSProcessState_iOS13
%hook RBSProcessState

- (id)initWithBSXPCCoder:(BSXPCCoder *)coder {
    return initProcessStateWithCoder(%orig, coder);
}

%end
%end

%group RBSProcessState_iOS14
%hook RBSProcessState

- (id)initWithRBSXPCCoder:(BSXPCCoder *)coder {
    return initProcessStateWithCoder(%orig, coder);
}

%end
%end

void initDecodeProcessStateHooks() {
    %init;
    if ([%c(RBSProcessState) instancesRespondToSelector:@selector(initWithBSXPCCoder:)]) {
        %init(RBSProcessState_iOS13);
    } else {
        %init(RBSProcessState_iOS14);
    }
}
